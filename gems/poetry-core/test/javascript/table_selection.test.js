import { beforeEach, describe, expect, it } from "vitest"
import { Application } from "@hotwired/stimulus"
import { registerPoetryControllers } from "@poetry/controllers"

// The table row-selection engine (, the SelectionManager contract,
// checkbox-flavored): select-all with a REAL indeterminate middle state
// over enabled rows, shift ranges off the anchor model, aria/data-selected
// mirroring, selection-change events, and the clear-selection listener.

const nextFrame = () => new Promise((resolve) => setTimeout(resolve, 0))

const IDENTIFIER = "poetry--core--table-selection"

const el = (id) => document.getElementById(id)

const row = (id, { checked = false, disabled = false } = {}) => `
  <tr id="${id}-row">
    <td>
      <input type="checkbox" id="${id}" value="${id}" name="selected_ids[]"
             data-slot="data-table-select-row" ${checked ? "checked" : ""} ${disabled ? "disabled" : ""}
             data-action="pointerdown->${IDENTIFIER}#press keydown->${IDENTIFIER}#press change->${IDENTIFIER}#toggled">
    </td>
    <td>${id}</td>
  </tr>`

const tableMarkup = (rows) => `
  <div id="wrapper">
    <div id="table" data-controller="${IDENTIFIER}">
      <table>
        <thead><tr><th>
          <input type="checkbox" id="all" data-${IDENTIFIER}-target="all"
                 data-action="change->${IDENTIFIER}#toggleAll">
        </th><th>Name</th></tr></thead>
        <tbody>${rows.join("\n")}</tbody>
      </table>
    </div>
  </div>`

const toggle = (id, { shift = false } = {}) => {
  const box = el(id)

  box.dispatchEvent(new MouseEvent("pointerdown", { bubbles: true, shiftKey: shift }))
  box.checked = !box.checked
  box.dispatchEvent(new Event("change", { bubbles: true }))
}

describe("poetry--core--table-selection", () => {
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

  async function mount(rows = [row("a"), row("b"), row("c"), row("d")]) {
    el("host").innerHTML = tableMarkup(rows)
    await nextFrame()
  }

  it("toggling a row mirrors aria-selected/data-selected and fires selection-change", async () => {
    await mount()

    const changes = []

    el("wrapper").addEventListener("poetry:data-table:selection-change",
      (event) => changes.push(event.detail))

    toggle("b")

    expect(el("b-row").hasAttribute("data-selected")).toBe(true)
    expect(el("b-row").getAttribute("aria-selected")).toBe("true")
    expect(changes.at(-1)).toEqual({ count: 1, values: ["b"] })
  })

  it("select-all checks every ENABLED row; the middle state is indeterminate (a property)", async () => {
    await mount([row("a"), row("b", { disabled: true }), row("c")])

    el("all").checked = true
    el("all").dispatchEvent(new Event("change", { bubbles: true }))

    expect(el("a").checked).toBe(true)
    expect(el("b").checked).toBe(false) // disabled: skipped
    expect(el("c").checked).toBe(true)
    expect(el("all").indeterminate).toBe(false)

    toggle("c") // down to a partial selection

    expect(el("all").checked).toBe(false)
    expect(el("all").indeterminate).toBe(true)
  })

  it("shift-click sets the whole anchor..target span to the anchor's state, skipping disabled", async () => {
    await mount([row("a"), row("b"), row("c", { disabled: true }), row("d")])

    toggle("a") // anchor, now checked
    toggle("d", { shift: true })

    expect(el("a").checked).toBe(true)
    expect(el("b").checked).toBe(true)
    expect(el("c").checked).toBe(false) // disabled: never ranged
    expect(el("d").checked).toBe(true)
  })

  it("clear-selection bubbling from anywhere in the wrapper empties everything", async () => {
    await mount()

    toggle("a")
    toggle("b")

    el("table").dispatchEvent(
      new CustomEvent("poetry:data-table:clear-selection", { bubbles: true })
    )

    expect(el("a").checked).toBe(false)
    expect(el("b").checked).toBe(false)
    expect(el("a-row").hasAttribute("data-selected")).toBe(false)
    expect(el("all").indeterminate).toBe(false)
  })
})
