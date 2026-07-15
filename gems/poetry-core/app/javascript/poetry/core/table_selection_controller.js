import { Controller } from "@hotwired/stimulus"
import { announce } from "@poetry/controllers/helpers/announce"

// The table row-selection engine (, the react-aria SelectionManager
// contract, checkbox-flavored): per-row checkboxes are the form value
// (selected_ids[] - no JS means plain checkboxes in a form, the honest
// fallback), this controller adds what HTML cannot:
//
// - select-all with a real INDETERMINATE middle state (a JS property,
//   never an attribute), computed over ENABLED rows only (disabled rows
//   are skipped by select-all and ranges - disabledBehavior 'selection').
// - Shift-click range selection off the react-aria ANCHOR model: the
//   anchor is the last plainly-toggled row; Shift sets every row in
//   anchor..target to the ANCHOR row's state (the checkbox idiom).
// - aria-selected + data-selected mirrored onto rows, count announcements
//   through the announce singleton, and a bubbling selection-change event
//   the ActionBar block feeds on.
// - poetry:data-table:clear-selection (dispatched by the ActionBar's
//   Escape) clears everything from anywhere inside the wrapper.
const EVENT_PREFIX = "poetry:data-table"

export default class TableSelectionController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:data-table:selection-change"]

  static targets = ["all"]
  static values = {
    label: { type: String, default: "%{count} selected" }
  }

  #anchor = null
  #onClear = () => this.#clearAll()

  connect() {
    this.element.addEventListener("poetry:data-table:clear-selection", this.#onClear)
    this.#reflect({ announceCount: false })
  }

  disconnect() {
    this.element.removeEventListener("poetry:data-table:clear-selection", this.#onClear)
  }

  // change on a ROW checkbox (data-action). Shift ranges ride the click
  // that produced the change (shiftKey survives on the change event's
  // originating input via the captured state below).
  toggled(event) {
    const checkbox = event.target

    if (this.#shiftRange && this.#anchor && this.#anchor !== checkbox) {
      this.#applyRange(this.#anchor, checkbox)
    } else {
      this.#anchor = checkbox
    }

    this.#shiftRange = false
    this.#reflect()
  }

  // pointerdown/keydown seam: remember whether the NEXT change was a
  // shift-gesture (change events themselves carry no modifiers).
  press(event) {
    this.#shiftRange = event.shiftKey === true
  }

  // change on the select-all checkbox.
  toggleAll(event) {
    const target = event.target.checked

    for (const checkbox of this.#rowCheckboxes()) {
      if (checkbox.disabled) continue

      checkbox.checked = target
    }

    this.#anchor = null
    this.#reflect()
  }

  #shiftRange = false

  #applyRange(anchor, target) {
    const boxes = this.#rowCheckboxes()
    const from = boxes.indexOf(anchor)
    const to = boxes.indexOf(target)

    if (from === -1 || to === -1) return

    const state = anchor.checked

    for (const checkbox of boxes.slice(Math.min(from, to), Math.max(from, to) + 1)) {
      if (checkbox.disabled) continue

      checkbox.checked = state
    }
  }

  #clearAll() {
    for (const checkbox of this.#rowCheckboxes()) checkbox.checked = false

    this.#anchor = null
    this.#reflect()
  }

  #reflect({ announceCount = true } = {}) {
    const boxes = this.#rowCheckboxes()
    const enabled = boxes.filter((checkbox) => !checkbox.disabled)
    const selected = boxes.filter((checkbox) => checkbox.checked)

    for (const checkbox of boxes) {
      const row = checkbox.closest("tr")

      if (!row) continue

      row.toggleAttribute("data-selected", checkbox.checked)
      row.setAttribute("aria-selected", String(checkbox.checked))
    }

    if (this.hasAllTarget) {
      this.allTarget.checked = enabled.length > 0 && selected.length === enabled.length
      this.allTarget.indeterminate = selected.length > 0 && selected.length < enabled.length
    }

    const count = selected.length

    if (announceCount) announce(this.labelValue.replace("%{count}", String(count)))

    this.dispatch("selection-change", {
      prefix: EVENT_PREFIX,
      detail: { count, values: selected.map((checkbox) => checkbox.value) }
    })
  }

  #rowCheckboxes() {
    return Array.from(this.element.querySelectorAll("[data-slot='data-table-select-row']"))
  }
}
