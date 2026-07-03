import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--pressed JS-unit: the Toggle micro-machine - aria-pressed
// and data-state=on|off flipped TOGETHER, the cancelable change event, the
// disabled guard, and the programmatic press/unpress/set surface. No other
// attributes are touched (the vocabulary-discipline assertion).

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
const el = (id) => document.getElementById(id)

const click = (element) =>
  element.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }))

async function mount({ pressed = false, disabled = false } = {}) {
  document.body.innerHTML = `
    <button type="button" id="toggle" data-slot="toggle" data-component="toggle"
            aria-pressed="${pressed}" data-state="${pressed ? "on" : "off"}"
            ${disabled ? "disabled" : ""}
            data-controller="poetry--core--pressed"
            data-action="poetry--core--pressed#toggle">Bookmark</button>`
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

const controller = (application) =>
  application.getControllerForElementAndIdentifier(el("toggle"), "poetry--core--pressed")

describe("poetry--core--pressed", () => {
  let application

  beforeEach(async () => {
    application = await mount()
    return async () => {
      document.body.replaceChildren()
      await nextFrame()
      application.stop()
    }
  })

  it("toggle flips aria-pressed AND data-state together", () => {
    click(el("toggle"))
    expect(el("toggle").getAttribute("aria-pressed")).toBe("true")
    expect(el("toggle").dataset.state).toBe("on")

    click(el("toggle"))
    expect(el("toggle").getAttribute("aria-pressed")).toBe("false")
    expect(el("toggle").dataset.state).toBe("off")
  })

  it("dispatches poetry:toggle:change with the entering pressed state", () => {
    const seen = []
    el("toggle").addEventListener("poetry:toggle:change", (event) => seen.push(event.detail))

    click(el("toggle"))
    click(el("toggle"))

    expect(seen).toEqual([{ pressed: true }, { pressed: false }])
  })

  it("the change event is cancelable: preventDefault vetoes the flip", () => {
    el("toggle").addEventListener("poetry:toggle:change", (event) => event.preventDefault())

    click(el("toggle"))

    expect(el("toggle").getAttribute("aria-pressed")).toBe("false")
    expect(el("toggle").dataset.state).toBe("off")
  })

  it("press/unpress/set are the programmatic surface (the rollback recipe)", () => {
    controller(application).press()
    expect(el("toggle").dataset.state).toBe("on")

    controller(application).unpress()
    expect(el("toggle").dataset.state).toBe("off")

    controller(application).set(true)
    expect(el("toggle").getAttribute("aria-pressed")).toBe("true")
  })

  it("disabled guard: toggle and set are no-ops", async () => {
    application.stop()
    application = await mount({ disabled: true })

    click(el("toggle"))
    controller(application).set(true)

    expect(el("toggle").getAttribute("aria-pressed")).toBe("false")
    expect(el("toggle").dataset.state).toBe("off")
  })

  it("touches no other attributes (no aria-checked / aria-expanded leak)", () => {
    click(el("toggle"))

    expect(el("toggle").hasAttribute("aria-checked")).toBe(false)
    expect(el("toggle").hasAttribute("aria-expanded")).toBe(false)
  })
})
