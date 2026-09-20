import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// poetry--core--checkbox-group JS-unit: the select-all recipe (Base UI
// CheckboxGroup's parent checkbox, APG mixed-state) over the checked
// family. What this file proves: parent fan-out to enabled rows, row
// toggles re-deriving the parent (all/none/some -> checked/unchecked/
// indeterminate), disabled rows out of both directions, no feedback loop
// (a row toggle never fans out; the parent echo is deduped), and the
// group observe event's count/total.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))
const el = (id) => document.getElementById(id)

const checkedAttrs = (element) =>
  ["data-checked", "data-unchecked", "data-indeterminate"].filter((name) => element.hasAttribute(name))

const click = (element) =>
  element.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }))

// Visual-only checkboxes (no input id) - the docs table recipe: row
// selection is controlled UI, not a form value.
const box = ({ id, state = "unchecked", target, disabled = false }) => `
  <button type="button" id="${id}" role="checkbox" data-slot="checkbox" data-component="checkbox"
          aria-checked="${state === "indeterminate" ? "mixed" : state === "checked"}"
          data-${state} ${disabled ? "disabled" : ""}
          data-controller="poetry--core--checked"
          data-poetry--core--checkbox-group-target="${target}"
          data-action="poetry--core--checked#toggle">
    <span data-slot="checkbox-indicator" aria-hidden="true" data-${state}></span>
  </button>`

const markup = (rows) => `
  <div id="group" data-controller="poetry--core--checkbox-group"
       data-action="poetry:checkbox:change->poetry--core--checkbox-group#changed">
    ${box({ id: "all", state: "indeterminate", target: "all" })}
    ${rows.map((row, index) => box({ id: `row-${index + 1}`, target: "item", ...row })).join("")}
  </div>`

async function mount(rows) {
  document.body.innerHTML = markup(rows)
  const application = Application.start()
  registerPoetryControllers(application)
  await nextFrame()
  return application
}

describe("poetry--core--checkbox-group", () => {
  let application

  beforeEach(async () => {
    application = await mount([{ state: "checked" }, {}, { state: "checked" }])
    return async () => {
      document.body.replaceChildren()
      await nextFrame()
      application.stop()
    }
  })

  it("the parent fans out to every row: indeterminate resolves to select-all, the next toggle selects none", () => {
    click(el("all"))

    for (const id of ["row-1", "row-2", "row-3"]) {
      expect(checkedAttrs(el(id))).toEqual(["data-checked"])
      expect(el(id).getAttribute("aria-checked")).toBe("true")
    }
    expect(checkedAttrs(el("all"))).toEqual(["data-checked"])

    click(el("all"))

    for (const id of ["all", "row-1", "row-2", "row-3"]) {
      expect(checkedAttrs(el(id))).toEqual(["data-unchecked"])
    }
  })

  it("row toggles re-derive the parent (all -> checked, some -> indeterminate, none -> unchecked) without touching siblings", () => {
    click(el("row-2")) // 3/3

    expect(checkedAttrs(el("all"))).toEqual(["data-checked"])
    expect(el("all").getAttribute("aria-checked")).toBe("true")

    click(el("row-2")) // 2/3 - and the parent reflection must NOT fan out

    expect(checkedAttrs(el("all"))).toEqual(["data-indeterminate"])
    expect(el("all").getAttribute("aria-checked")).toBe("mixed")
    expect(checkedAttrs(el("row-1"))).toEqual(["data-checked"])
    expect(checkedAttrs(el("row-3"))).toEqual(["data-checked"])

    click(el("row-1"))
    click(el("row-3")) // 0/3

    expect(checkedAttrs(el("all"))).toEqual(["data-unchecked"])
    expect(checkedAttrs(el("row-2"))).toEqual(["data-unchecked"])
  })

  it("disabled rows are skipped by fan-out and excluded from the derivation", async () => {
    application.stop()
    application = await mount([{}, { disabled: true }, {}])

    click(el("all")) // indeterminate -> checked

    expect(checkedAttrs(el("row-1"))).toEqual(["data-checked"])
    expect(checkedAttrs(el("row-2"))).toEqual(["data-unchecked"])
    expect(checkedAttrs(el("row-3"))).toEqual(["data-checked"])
    // 2/2 ENABLED rows selected reads as all-selected, not mixed
    expect(checkedAttrs(el("all"))).toEqual(["data-checked"])
  })

  it("a row toggle that leaves the parent state unchanged does not re-dispatch the parent's change", () => {
    const parentEvents = []
    el("all").addEventListener("poetry:checkbox:change", (event) => parentEvents.push(event.detail))

    click(el("row-1")) // 1/3 - still indeterminate

    expect(checkedAttrs(el("all"))).toEqual(["data-indeterminate"])
    expect(parentEvents).toEqual([])
  })

  it("dispatches the group observe event with count/total after either direction", () => {
    const seen = []
    el("group").addEventListener("poetry:checkbox-group:change", (event) => seen.push(event.detail))

    click(el("all"))
    click(el("row-2"))

    expect(seen).toEqual([{ count: 3, total: 3 }, { count: 2, total: 3 }])
  })
})
