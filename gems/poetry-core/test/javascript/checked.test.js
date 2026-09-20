import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--checked JS-unit: the toggle family's shared checked machine
// (Checkbox tri-state + Switch binary, one controller, zero fork). What
// this file proves: the store inversion (input written FIRST, a REAL
// bubbling change event), aria-checked/the checked pair written together across
// control + parts, indeterminate resolution + re-entry via set(), the
// Enter guard keyed off role=checkbox, form-reset re-sync, and the
// visual-only (no input id) mode.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
const nextAnimationFrame = () => new Promise((resolve) => requestAnimationFrame(() => resolve()))
const el = (id) => document.getElementById(id)

// The checked-family pair discipline: exactly ONE of the three attributes
// present at any time (setState removes the counterparts).
const checkedAttrs = (element) =>
  ["data-checked", "data-unchecked", "data-indeterminate"].filter((name) => element.hasAttribute(name))

const click = (element) =>
  element.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }))

const markup = ({ state = "unchecked", role = "checkbox", inputId = "box-input", disabled = false, component = "checkbox" } = {}) => `
  <form id="form">
    <button type="button" id="box" role="${role}" data-slot="${component}" data-component="${component}"
            aria-checked="${state === "indeterminate" ? "mixed" : state === "checked"}"
            data-${state} ${disabled ? "disabled" : ""}
            data-controller="poetry--core--checked"
            ${inputId ? `data-poetry--core--checked-input-id-value="${inputId}"` : ""}
            data-action="poetry--core--checked#toggle">
      <span id="indicator" data-slot="${component}-indicator" aria-hidden="true" data-${state}></span>
    </button>
    ${inputId ? `
      <input type="hidden" name="pref" value="0">
      <input type="checkbox" id="${inputId}" name="pref" value="1"
             ${state === "checked" ? "checked" : ""} ${disabled ? "disabled" : ""}
             aria-hidden="true" tabindex="-1" class="sr-only">` : ""}
  </form>`

const controllerFor = (application, element) =>
  application.getControllerForElementAndIdentifier(element, "poetry--core--checked")

async function mount(options = {}) {
  document.body.innerHTML = markup(options)
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

describe("poetry--core--checked", () => {
  let application

  beforeEach(async () => {
    application = await mount()
    return async () => {
      document.body.replaceChildren()
      await nextFrame()
      application.stop()
    }
  })

  it("toggle flips the input FIRST, dispatches a real bubbling change, then reflects aria + the checked pair on control and parts", async () => {
    const seen = []
    el("form").addEventListener("change", (event) => {
      // The store inversion: by the time the change event bubbles, the
      // input already holds the new state.
      seen.push({ target: event.target.id, checked: event.target.checked })
    })

    click(el("box"))

    expect(seen).toEqual([{ target: "box-input", checked: true }])
    expect(el("box-input").checked).toBe(true)
    expect(el("box").getAttribute("aria-checked")).toBe("true")
    expect(checkedAttrs(el("box"))).toEqual(["data-checked"])
    expect(checkedAttrs(el("indicator"))).toEqual(["data-checked"])

    click(el("box"))

    expect(el("box-input").checked).toBe(false)
    expect(el("box").getAttribute("aria-checked")).toBe("false")
    expect(checkedAttrs(el("box"))).toEqual(["data-unchecked"])
    expect(checkedAttrs(el("indicator"))).toEqual(["data-unchecked"])
  })

  it("dispatches the component-flavored observe event (poetry:checkbox:change)", async () => {
    const seen = []
    el("box").addEventListener("poetry:checkbox:change", (event) => seen.push(event.detail))

    click(el("box"))

    expect(seen).toEqual([{ checked: true, was_indeterminate: false }])
  })

  it("indeterminate resolves to CHECKED on the first toggle (Radix-exact)", async () => {
    application.stop()
    application = await mount({ state: "indeterminate" })

    // connect derived the JS-only property from the checked attributes
    expect(el("box-input").indeterminate).toBe(true)
    expect(el("box-input").checked).toBe(false)

    click(el("box"))

    expect(el("box-input").indeterminate).toBe(false)
    expect(el("box-input").checked).toBe(true)
    expect(el("box").getAttribute("aria-checked")).toBe("true")
    expect(checkedAttrs(el("box"))).toEqual(["data-checked"])
  })

  it("set() reaches all three states incl. back to indeterminate (the select-all recipe)", async () => {
    const controller = controllerFor(application, el("box"))

    controller.check()
    expect(checkedAttrs(el("box"))).toEqual(["data-checked"])
    expect(el("box-input").checked).toBe(true)

    controller.set("indeterminate")
    expect(el("box").getAttribute("aria-checked")).toBe("mixed")
    expect(checkedAttrs(el("box"))).toEqual(["data-indeterminate"])
    expect(checkedAttrs(el("indicator"))).toEqual(["data-indeterminate"])
    expect(el("box-input").indeterminate).toBe(true)
    expect(el("box-input").checked).toBe(false)

    controller.uncheck()
    expect(checkedAttrs(el("box"))).toEqual(["data-unchecked"])
    expect(el("box-input").indeterminate).toBe(false)
  })

  it("Enter is preventDefaulted on role=checkbox (Space-only activation)", () => {
    const enter = new KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true })
    el("box").dispatchEvent(enter)

    expect(enter.defaultPrevented).toBe(true)
  })

  it("role=switch does NOT suppress Enter (the Radix-exact asymmetry, no fork)", async () => {
    application.stop()
    application = await mount({ role: "switch", component: "switch" })

    const enter = new KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true })
    el("box").dispatchEvent(enter)

    expect(enter.defaultPrevented).toBe(false)

    // and the switch flavor of the observe event fires
    const seen = []
    el("box").addEventListener("poetry:switch:change", (event) => seen.push(event.detail))
    click(el("box"))
    expect(seen).toEqual([{ checked: true, was_indeterminate: false }])
    expect(checkedAttrs(el("indicator"))).toEqual(["data-checked"]) // the thumb mirrors
  })

  it("form reset re-syncs the visuals from the input (rAF-deferred)", async () => {
    click(el("box"))
    expect(checkedAttrs(el("box"))).toEqual(["data-checked"])

    el("form").reset()
    await nextAnimationFrame() // reset restore + the controller's rAF

    expect(el("box-input").checked).toBe(false)
    expect(el("box").getAttribute("aria-checked")).toBe("false")
    expect(checkedAttrs(el("box"))).toEqual(["data-unchecked"])
    expect(checkedAttrs(el("indicator"))).toEqual(["data-unchecked"])
  })

  it("form reset restores a server-rendered indeterminate initial state", async () => {
    application.stop()
    application = await mount({ state: "indeterminate" })

    click(el("box")) // resolves to checked
    el("form").reset()
    await nextAnimationFrame()

    expect(el("box-input").indeterminate).toBe(true)
    expect(el("box").getAttribute("aria-checked")).toBe("mixed")
    expect(checkedAttrs(el("box"))).toEqual(["data-indeterminate"])
  })

  it("disabled guard: toggle is a no-op", async () => {
    application.stop()
    application = await mount({ disabled: true })

    click(el("box"))

    expect(checkedAttrs(el("box"))).toEqual(["data-unchecked"])
    expect(el("box-input").checked).toBe(false)
  })

  it("visual-only mode (no input id): state lives on the button checked attributes alone", async () => {
    application.stop()
    application = await mount({ inputId: null })

    click(el("box"))

    expect(checkedAttrs(el("box"))).toEqual(["data-checked"])
    expect(el("box").getAttribute("aria-checked")).toBe("true")
    expect(document.querySelector("input[type=checkbox]")).toBe(null)
  })

  it("reconcile-on-connect adopts the server-rendered checked state into the input", async () => {
    application.stop()
    document.body.innerHTML = markup({ state: "checked" })
    // simulate a Turbo re-render where the checked ATTRIBUTE was not carried
    el("box-input").removeAttribute("checked")

    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()

    expect(el("box-input").checked).toBe(true) // the checked attribute pair (server truth) won
  })
})
