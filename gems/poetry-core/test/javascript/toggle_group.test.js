import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--toggle-group JS-unit: the value-set machine (single {v}<->{}
// with deselect-to-empty, multiple XOR), the two-vocabulary discipline
// (single = aria-checked radios, multiple = aria-pressed toggles - never
// both), the change payload, the pressed-item tab-stop preference, and the
// roving-focus composition (one tab stop, arrows move without selecting).

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
const el = (id) => document.getElementById(id)

const click = (element) =>
  element.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }))

const press = (element, key) =>
  element.dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true }))

const markup = ({ type = "single", pressed = [], disabledItems = [] } = {}) => {
  const item = (value) => {
    const on = pressed.includes(value)
    const aria = type === "single"
      ? `role="radio" aria-checked="${on}"`
      : `aria-pressed="${on}"`
    return `
      <button type="button" id="item-${value}" data-slot="toggle-group-item"
              data-poetry-collection-item data-value="${value}" ${aria}
              data-state="${on ? "on" : "off"}"
              ${disabledItems.includes(value) ? "disabled data-disabled" : ""}
              tabindex="${pressed.includes(value) ? 0 : -1}"
              data-action="poetry--core--toggle-group#toggle">${value}</button>`
  }
  return `
    <div id="group" data-slot="toggle-group" data-component="toggle-group"
         role="${type === "single" ? "radiogroup" : "toolbar"}"
         data-controller="poetry--core--toggle-group poetry--core--roving-focus"
         data-poetry--core--toggle-group-type-value="${type}"
         data-poetry--core--roving-focus-orientation-value="horizontal"
         data-poetry--core--roving-focus-loop-value="true"
         data-action="keydown->poetry--core--roving-focus#keydown"
         aria-label="Formatting">
      ${item("bold")}${item("italic")}${item("underline")}
    </div>`
}

const controller = (application) =>
  application.getControllerForElementAndIdentifier(el("group"), "poetry--core--toggle-group")

const states = () => ["bold", "italic", "underline"].map((v) => el(`item-${v}`).dataset.state)
const tabindexes = () => ["bold", "italic", "underline"].map((v) => el(`item-${v}`).getAttribute("tabindex"))

async function mount(options = {}) {
  document.body.innerHTML = markup(options)
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

describe("poetry--core--toggle-group", () => {
  let application

  beforeEach(async () => {
    application = await mount()
    return async () => {
      document.body.replaceChildren()
      await nextFrame()
      application.stop()
    }
  })

  describe("type=single (radiogroup semantics)", () => {
    it("pressing an item unpresses the previous one and writes aria-checked (never aria-pressed)", () => {
      click(el("item-bold"))

      expect(states()).toEqual(["on", "off", "off"])
      expect(el("item-bold").getAttribute("aria-checked")).toBe("true")
      expect(el("item-bold").hasAttribute("aria-pressed")).toBe(false)

      click(el("item-italic"))

      expect(states()).toEqual(["off", "on", "off"])
      expect(el("item-bold").getAttribute("aria-checked")).toBe("false")
      expect(el("item-italic").getAttribute("aria-checked")).toBe("true")
    })

    it("re-pressing the pressed item deselects to EMPTY (Radix-exact)", () => {
      click(el("item-bold"))
      click(el("item-bold"))

      expect(states()).toEqual(["off", "off", "off"])
      expect(el("item-bold").getAttribute("aria-checked")).toBe("false")
    })

    it("the change payload carries value + pressed/unpressed transitions", () => {
      const seen = []
      el("group").addEventListener("poetry:toggle-group:change", (event) => seen.push(event.detail))

      click(el("item-bold"))
      click(el("item-italic"))
      click(el("item-italic"))

      expect(seen).toEqual([
        { type: "single", value: "bold", pressed: ["bold"], unpressed: [] },
        { type: "single", value: "italic", pressed: ["italic"], unpressed: ["bold"] },
        { type: "single", value: null, pressed: [], unpressed: ["italic"] }
      ])
    })

    it("the pressed item becomes the roving tab stop (active=pressed)", () => {
      click(el("item-italic"))
      expect(tabindexes()).toEqual(["-1", "0", "-1"])
    })

    it("arrows move focus WITHOUT selecting (the Radix deviation from APG radio)", () => {
      click(el("item-bold"))
      el("item-bold").focus()
      press(el("item-bold"), "ArrowRight")

      expect(document.activeElement).toBe(el("item-italic"))
      expect(states()).toEqual(["on", "off", "off"]) // focus moved, selection did not
    })
  })

  describe("type=multiple (toolbar semantics)", () => {
    beforeEach(async () => {
      application.stop()
      application = await mount({ type: "multiple" })
    })

    it("items toggle independently (XOR) and write aria-pressed (never aria-checked)", () => {
      click(el("item-bold"))
      click(el("item-underline"))

      expect(states()).toEqual(["on", "off", "on"])
      expect(el("item-bold").getAttribute("aria-pressed")).toBe("true")
      expect(el("item-bold").hasAttribute("aria-checked")).toBe(false)

      click(el("item-bold"))
      expect(states()).toEqual(["off", "off", "on"])
    })

    it("the change payload carries the values array", () => {
      const seen = []
      el("group").addEventListener("poetry:toggle-group:change", (event) => seen.push(event.detail))

      click(el("item-bold"))
      click(el("item-italic"))

      expect(seen[0]).toEqual({ type: "multiple", values: ["bold"], pressed: ["bold"], unpressed: [] })
      expect(seen[1]).toEqual({ type: "multiple", values: ["bold", "italic"], pressed: ["italic"], unpressed: [] })
    })

    it("setValue applies an array; a bare string is rejected", () => {
      controller(application).setValue(["bold", "underline"])
      expect(states()).toEqual(["on", "off", "on"])

      controller(application).setValue("italic")
      expect(states()).toEqual(["on", "off", "on"]) // rejected - type mismatch
    })
  })

  it("setValue in single mode applies one value, clears with null, ignores unknown values", () => {
    controller(application).setValue("italic")
    expect(states()).toEqual(["off", "on", "off"])

    controller(application).setValue("nope")
    expect(states()).toEqual(["off", "off", "off"]) // unknown filtered -> empty set

    controller(application).setValue("bold")
    controller(application).setValue(null)
    expect(states()).toEqual(["off", "off", "off"])
  })

  it("disabled items cannot be toggled and are skipped by the roving arrows", async () => {
    application.stop()
    application = await mount({ disabledItems: ["italic"] })

    click(el("item-italic"))
    expect(states()).toEqual(["off", "off", "off"])

    el("item-bold").focus()
    press(el("item-bold"), "ArrowRight")
    expect(document.activeElement).toBe(el("item-underline")) // italic filtered out
  })

  it("reconcile-on-connect derives the type-correct aria from server-rendered data-state", async () => {
    application.stop()
    document.body.innerHTML = markup({ type: "single", pressed: ["italic"] })
    // simulate a mixed-vocabulary server render: single item wearing aria-pressed
    el("item-italic").setAttribute("aria-pressed", "true")
    el("item-italic").removeAttribute("aria-checked")

    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()

    expect(el("item-italic").getAttribute("aria-checked")).toBe("true")
    expect(el("item-italic").hasAttribute("aria-pressed")).toBe(false)
    expect(tabindexes()).toEqual(["-1", "0", "-1"]) // pressed item is the stamped stop
  })
})
