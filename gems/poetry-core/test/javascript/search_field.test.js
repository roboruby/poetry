import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// The SearchField seams: Escape clears-and-consumes a non-empty
// field but PROPAGATES from an empty one (the next press reaches the
// dismissal layer); emptiness reads the RAW input value; the clear button
// keeps focus in the input; clearing fires a REAL input event.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const IDENTIFIER = "poetry--core--search-field"

const el = (id) => document.getElementById(id)

const markup = ({ value = "", disabled = "", readonly = "" } = {}) => `
  <div id="field" data-controller="${IDENTIFIER}" ${value === "" ? "data-empty" : ""}>
    <input id="input" type="search" value="${value}" ${disabled} ${readonly}
           data-${IDENTIFIER}-target="input"
           data-action="input->${IDENTIFIER}#changed keydown->${IDENTIFIER}#keydown">
    <button id="clear" tabindex="-1" ${value === "" ? "hidden" : ""}
            data-${IDENTIFIER}-target="clear"
            data-action="pointerdown->${IDENTIFIER}#holdFocus click->${IDENTIFIER}#clear">×</button>
  </div>`

const escape = (options = {}) => {
  const event = new KeyboardEvent("keydown", {
    key: "Escape", bubbles: true, cancelable: true, ...options
  })

  el("input").dispatchEvent(event)
  return event
}

describe("poetry--core--search-field", () => {
  let application

  beforeEach(async () => {
    document.body.innerHTML = `<div id="host"></div>`
    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()
    return async () => {
      el("host")?.replaceChildren()
      await nextFrame()
      application.stop()
    }
  })

  async function mount(options = {}) {
    el("host").innerHTML = markup(options)
    await nextFrame()
  }

  it("Escape on a NON-empty field clears, consumes, and fires a real input event", async () => {
    await mount({ value: "ruby" })

    const inputs = []

    el("input").addEventListener("input", () => inputs.push(el("input").value))

    const cleared = []

    el("field").addEventListener("poetry:search-field:clear", () => cleared.push(true))

    const event = escape()

    expect(el("input").value).toBe("")
    expect(event.defaultPrevented).toBe(true)
    expect(inputs).toEqual([""])
    expect(cleared).toEqual([true])
    expect(el("field").hasAttribute("data-empty")).toBe(true)
    expect(el("clear").hidden).toBe(true)
  })

  it("Escape on an EMPTY field propagates untouched (the dismissal layer's turn)", async () => {
    await mount({ value: "" })

    const event = escape()

    expect(event.defaultPrevented).toBe(false)
  })

  it("emptiness reads the RAW value - a script-poked input still clears", async () => {
    await mount({ value: "" })

    el("input").value = "poked" // no input event fired

    const event = escape()

    expect(event.defaultPrevented).toBe(true)
    expect(el("input").value).toBe("")
  })

  it("an IME Escape never clears", async () => {
    await mount({ value: "ruby" })

    const event = escape({ isComposing: true })

    expect(event.defaultPrevented).toBe(false)
    expect(el("input").value).toBe("ruby")
  })

  it("readonly and disabled fields ignore Escape-clear", async () => {
    await mount({ value: "ruby", readonly: "readonly" })

    const event = escape()

    expect(event.defaultPrevented).toBe(false)
    expect(el("input").value).toBe("ruby")
  })

  it("the clear button clears, refocuses the input, and its press never steals focus", async () => {
    await mount({ value: "ruby" })

    const press = new MouseEvent("pointerdown", { bubbles: true, cancelable: true })

    el("clear").dispatchEvent(press)
    expect(press.defaultPrevented).toBe(true) // focus stays in the input
    expect(document.activeElement).toBe(el("input"))

    el("clear").dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }))

    expect(el("input").value).toBe("")
    expect(el("clear").hidden).toBe(true)
    expect(document.activeElement).toBe(el("input"))
  })

  it("typing reflects data-empty and reveals the clear affordance", async () => {
    await mount({ value: "" })

    el("input").value = "r"
    el("input").dispatchEvent(new Event("input", { bubbles: true }))

    expect(el("field").hasAttribute("data-empty")).toBe(false)
    expect(el("clear").hidden).toBe(false)
  })
})
