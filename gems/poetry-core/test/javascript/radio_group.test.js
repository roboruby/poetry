import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--radio-group JS-unit: the checked-value machine - check()
// writes aria-checked/the checked pair/indicator/input.checked together + moves
// the tab stop + dispatches poetry:radio-group:change AND native
// input/change on the hidden input; re-check no-ops; selection follows
// focus via roving-focus's entry event (arrows check, Tab never does);
// disabled items unreachable; setValue programmatic surface.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
const el = (id) => document.getElementById(id)

const click = (element) =>
  element.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }))

const press = (element, key) =>
  element.dispatchEvent(new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true }))

const VALUES = ["comfortable", "compact", "dense"]

const markup = ({ value = "", disabledItems = [] } = {}) => {
  const item = (v) => {
    const checked = v === value
    return `
      <button type="button" role="radio" id="item-${v}" data-slot="radio-group-item"
              data-poetry-collection-item data-value="${v}"
              aria-checked="${checked}" ${checked ? "data-checked" : "data-unchecked"}
              tabindex="${checked || (value === "" && v === VALUES[0]) ? 0 : -1}"
              ${disabledItems.includes(v) ? "disabled data-disabled" : ""}
              data-action="poetry--core--radio-group#check">
        <span data-slot="radio-group-indicator" ${checked ? "" : "hidden"}></span>
        <input type="radio" name="density" value="${v}" ${checked ? "checked" : ""}
               ${disabledItems.includes(v) ? "disabled" : ""}
               aria-hidden="true" tabindex="-1" class="sr-only">
      </button>`
  }
  return `
    <form id="form">
      <div id="group" data-slot="radio-group" data-component="radio-group" role="radiogroup"
           aria-label="Density"
           data-controller="poetry--core--radio-group poetry--core--roving-focus"
           ${value ? `data-poetry--core--radio-group-value-value="${value}"` : ""}
           data-poetry--core--roving-focus-orientation-value="both"
           data-poetry--core--roving-focus-loop-value="true"
           data-action="keydown->poetry--core--roving-focus#keydown
                        poetry--core--roving-focus:entry->poetry--core--radio-group#entryCheck">
        ${VALUES.map(item).join("")}
      </div>
    </form>`
}

const controller = (application) =>
  application.getControllerForElementAndIdentifier(el("group"), "poetry--core--radio-group")

const ariaChecked = () => VALUES.map((v) => el(`item-${v}`).getAttribute("aria-checked"))
const inputChecked = () => VALUES.map((v) => el(`item-${v}`).querySelector("input").checked)
const tabindexes = () => VALUES.map((v) => el(`item-${v}`).getAttribute("tabindex"))

async function mount(options = {}) {
  document.body.innerHTML = markup(options)
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

describe("poetry--core--radio-group", () => {
  let application

  beforeEach(async () => {
    application = await mount()
    return async () => {
      document.body.replaceChildren()
      await nextFrame()
      application.stop()
    }
  })

  it("check writes aria-checked + the checked pair + indicator + input.checked together and moves the tab stop", () => {
    click(el("item-compact"))

    expect(ariaChecked()).toEqual(["false", "true", "false"])
    expect(el("item-compact").hasAttribute("data-checked")).toBe(true)
    expect(el("item-compact").hasAttribute("data-unchecked")).toBe(false)
    expect(el("item-compact").querySelector("[data-slot=radio-group-indicator]").hidden).toBe(false)
    expect(el("item-comfortable").querySelector("[data-slot=radio-group-indicator]").hidden).toBe(true)
    expect(inputChecked()).toEqual([false, true, false])
    expect(tabindexes()).toEqual(["-1", "0", "-1"])
  })

  it("dispatches poetry:radio-group:change + native input/change on the checked hidden input", () => {
    const seen = []
    el("group").addEventListener("poetry:radio-group:change", (event) => seen.push(event.detail))

    const native = []
    el("form").addEventListener("change", (event) => native.push([event.type, event.target.value]))
    el("form").addEventListener("input", (event) => native.push([event.type, event.target.value]))

    click(el("item-dense"))

    expect(seen).toEqual([{ value: "dense", previous: "" }])
    expect(native).toEqual([["input", "dense"], ["change", "dense"]])
  })

  it("re-checking the checked item no-ops (radios never uncheck; no event)", () => {
    click(el("item-compact"))

    const seen = []
    el("group").addEventListener("poetry:radio-group:change", (event) => seen.push(event.detail))

    click(el("item-compact"))

    expect(seen).toEqual([])
    expect(ariaChecked()).toEqual(["false", "true", "false"])
  })

  it("selection follows focus: arrows move AND check (all four - orientation both)", () => {
    click(el("item-comfortable"))
    el("item-comfortable").focus()

    press(el("item-comfortable"), "ArrowDown")
    expect(document.activeElement).toBe(el("item-compact"))
    expect(ariaChecked()).toEqual(["false", "true", "false"])

    press(el("item-compact"), "ArrowRight")
    expect(document.activeElement).toBe(el("item-dense"))
    expect(ariaChecked()).toEqual(["false", "false", "true"])

    press(el("item-dense"), "ArrowUp")
    expect(ariaChecked()).toEqual(["false", "true", "false"])
  })

  it("Home/End jump and check", () => {
    click(el("item-compact"))
    el("item-compact").focus()

    press(el("item-compact"), "End")
    expect(document.activeElement).toBe(el("item-dense"))
    expect(ariaChecked()).toEqual(["false", "false", "true"])

    press(el("item-dense"), "Home")
    expect(ariaChecked()).toEqual(["true", "false", "false"])
  })

  it("Tab-like focus never checks (only the roving entry event does)", () => {
    el("item-comfortable").focus() // programmatic/Tab focus - no entry event

    expect(ariaChecked()).toEqual(["false", "false", "false"])
  })

  it("disabled items are unreachable: click no-ops and arrows skip them", async () => {
    application.stop()
    application = await mount({ disabledItems: ["compact"] })

    click(el("item-compact"))
    expect(ariaChecked()).toEqual(["false", "false", "false"])

    el("item-comfortable").focus()
    press(el("item-comfortable"), "ArrowDown")

    expect(document.activeElement).toBe(el("item-dense")) // compact filtered from the collection
    expect(ariaChecked()).toEqual(["false", "false", "true"])
  })

  it("server-rendered value reconciles on connect (aria/input/tab-stop normalized)", async () => {
    application.stop()
    application = await mount({ value: "dense" })

    expect(ariaChecked()).toEqual(["false", "false", "true"])
    expect(inputChecked()).toEqual([false, false, true])
    expect(tabindexes()).toEqual(["-1", "-1", "0"])
  })

  it("connect adopts a DOM-rendered checked state into the Value when none was given", async () => {
    application.stop()
    document.body.innerHTML = markup()
    el("item-compact").setAttribute("aria-checked", "true")

    application = Application.start()
    registerPoetryControllers(application)
    await nextFrame()

    expect(controller(application).valueValue).toBe("compact")
  })

  it("setValue checks programmatically and ignores unknown values", () => {
    controller(application).setValue("compact")
    expect(ariaChecked()).toEqual(["false", "true", "false"])

    controller(application).setValue("nope")
    expect(ariaChecked()).toEqual(["false", "true", "false"])
  })
})
