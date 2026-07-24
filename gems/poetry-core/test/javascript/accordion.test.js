import { describe, it, expect, beforeEach, afterEach } from "vitest"
import { Application } from "@hotwired/stimulus"
import AccordionController from "@poetry/controllers/accordion_controller"

const ID = "poetry--core--accordion"
let application

function item(value, state = "closed") {
  return `
    <div data-slot="accordion-item" data-value="${value}" ${state === "open" ? "data-open" : "data-closed"}>
      <h3><button data-slot="accordion-trigger" aria-expanded="${state === "open"}"
                  data-action="${ID}#toggle">${value}</button></h3>
      <div data-slot="accordion-content" ${state === "open" ? "" : "hidden"}>panel ${value}</div>
    </div>`
}

async function mount({ type = "single", collapsible = false, items = ["a", "b", "c"], open = [] } = {}) {
  document.body.innerHTML = `
    <div data-controller="${ID}"
         data-${ID}-type-value="${type}"
         data-${ID}-collapsible-value="${collapsible}">
      ${items.map((v) => item(v, open.includes(v) ? "open" : "closed")).join("")}
    </div>`
  application = Application.start()
  application.register(ID, AccordionController)
  await Promise.resolve()
}

const trigger = (value) => document.querySelector(`[data-value="${value}"] button`)
const itemEl = (value) => document.querySelector(`[data-value="${value}"]`)
const panel = (value) => document.querySelector(`[data-value="${value}"] [data-slot="accordion-content"]`)

afterEach(() => { document.body.innerHTML = ""; application?.stop() })

describe("poetry--core--accordion", () => {
  // The 2026-07-04 W5 browser pass: a server-rendered-open item's trigger
  // must carry data-panel-open on CONNECT, not only after a toggle (the
  // #open path set it during interaction but connect skipped it - collapsible
  // reflected on connect, accordion did not).
  it("reflects data-panel-open onto the server-open trigger at connect", async () => {
    await mount({ open: ["b"] })

    expect(trigger("b").hasAttribute("data-panel-open")).toBe(true)
    expect(trigger("a").hasAttribute("data-panel-open")).toBe(false)
    expect(trigger("c").hasAttribute("data-panel-open")).toBe(false)
  })

  it("single: opening one closes the others", async () => {
    await mount({ open: ["a"] })
    trigger("b").click()

    expect(itemEl("b").hasAttribute("data-open")).toBe(true)
    expect(itemEl("a").hasAttribute("data-closed")).toBe(true)
    expect(panel("a").hidden).toBe(true)
    expect(panel("b").hidden).toBe(false)
    expect(trigger("b").getAttribute("aria-expanded")).toBe("true")
    expect(trigger("b").hasAttribute("data-panel-open")).toBe(true) // Base UI trigger parity
    expect(trigger("a").hasAttribute("data-panel-open")).toBe(false)
  })

  it("single non-collapsible: the open trigger is aria-disabled and a no-op", async () => {
    await mount({ open: ["a"] })

    expect(trigger("a").getAttribute("aria-disabled")).toBe("true")
    trigger("a").click()
    expect(itemEl("a").hasAttribute("data-open")).toBe(true)
  })

  it("single collapsible: the open item can close", async () => {
    await mount({ collapsible: true, open: ["a"] })

    expect(trigger("a").getAttribute("aria-disabled")).toBeNull()
    trigger("a").click()
    expect(itemEl("a").hasAttribute("data-closed")).toBe(true)
  })

  it("multiple: items open independently", async () => {
    await mount({ type: "multiple", open: ["a"] })
    trigger("b").click()

    expect(itemEl("a").hasAttribute("data-open")).toBe(true)
    expect(itemEl("b").hasAttribute("data-open")).toBe(true)
    trigger("a").click()
    expect(itemEl("a").hasAttribute("data-closed")).toBe(true)
  })

  it("measures the panel height var for the keyframes", async () => {
    await mount({ open: [] })
    trigger("a").click()

    expect(panel("a").style.getPropertyValue("--accordion-panel-height")).toMatch(/px$/)
  })

  // The resting-keyframe gate (flicker fix): data-transitioning rides only
  // the open/close window and clears on animationend, so the persistent
  // data-open:animate-accordion-down keyframe stays inert at rest and cannot
  // replay when a display:none -> visible toggle (a Tabs panel) re-runs it.
  it("marks data-transitioning only during the toggle, cleared on animationend", async () => {
    await mount({ collapsible: true, open: [] })
    const p = panel("a")

    trigger("a").click() // open
    expect(p.hasAttribute("data-transitioning")).toBe(true)

    p.dispatchEvent(new Event("animationend")) // the expand keyframe completes
    expect(p.hasAttribute("data-transitioning")).toBe(false)

    trigger("a").click() // close - the window re-opens for the collapse keyframe
    expect(p.hasAttribute("data-transitioning")).toBe(true)
  })

  it("dispatches change with the open values", async () => {
    await mount({ type: "multiple" })
    let detail
    document.addEventListener(`${ID}:change`, (e) => { detail = e.detail })
    trigger("a").click()
    trigger("c").click()

    expect(detail.values).toEqual(["a", "c"])
  })
})
