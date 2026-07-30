import { Controller } from "@hotwired/stimulus"
import { stateOf } from "@poetry/controllers/helpers/state"

// The select-all recipe (Base UI CheckboxGroup's parent checkbox, the APG
// mixed-state pattern) over the checked family. Wrap the parent and its
// rows, route the bubbling per-checkbox observe event at #changed, and
// mark the parent (target: all) plus each row (target: item):
//
//   <div data-controller="poetry--core--checkbox-group"
//        data-action="poetry:checkbox:change->poetry--core--checkbox-group#changed">
//
// A parent toggle fans its new state out to every enabled row; a row
// toggle re-derives the parent (all -> checked, none -> unchecked, some ->
// indeterminate, re-entered via the checked controller's set() - the only
// path back to mixed). Every state write goes THROUGH each box's checked
// controller (input first, real change event, aria-checked + the checked
// triple together) - this controller never touches attributes itself.
// Disabled rows are skipped by fan-out and excluded from the derivation
// (the DataTable disabledBehavior 'selection' doctrine;
// table_selection_controller is this same recipe for NATIVE checkboxes).
const EVENT_PREFIX = "poetry:checkbox-group"

export default class CheckboxGroupController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:checkbox-group:change"]

  static targets = ["all", "item"]

  #applying = false

  // The wrapper's data-action route for every bubbling checkbox change.
  // #applying mutes the echoes our own set() calls dispatch (a fan-out
  // must not re-derive per row; a parent reflection must not fan out).
  changed(event) {
    if (this.#applying) return

    const fromParent = this.hasAllTarget && event.target === this.allTarget

    if (!fromParent && !this.itemTargets.includes(event.target)) return
    if (fromParent) this.#fanOut(event.detail.checked)

    // After a fan-out too: rows that refused (all disabled) snap the
    // parent back to what the roster actually holds.
    this.#reflectParent()

    const enabled = this.#enabled()

    this.dispatch("change", {
      prefix: EVENT_PREFIX,
      detail: { count: this.#checked(enabled).length, total: enabled.length }
    })
  }

  #fanOut(checked) {
    this.#applying = true
    for (const item of this.#enabled()) this.#checkedController(item)?.set(checked)
    this.#applying = false
  }

  #reflectParent() {
    if (!this.hasAllTarget) return

    const enabled = this.#enabled()
    const checked = this.#checked(enabled).length
    const state = checked === 0 ? "unchecked" : (checked === enabled.length ? "checked" : "indeterminate")

    // Dedupe: a row toggle that leaves the parent where it was (one of
    // several rows unchecked) must not re-dispatch the parent's change.
    if (stateOf(this.allTarget) === state) return

    this.#applying = true
    this.#checkedController(this.allTarget)?.set(state === "indeterminate" ? state : state === "checked")
    this.#applying = false
  }

  #checked(items) {
    return items.filter((item) => stateOf(item) === "checked")
  }

  #enabled() {
    return this.itemTargets.filter(
      (item) => !item.hasAttribute("disabled") && item.getAttribute("aria-disabled") !== "true"
    )
  }

  #checkedController(element) {
    return this.application.getControllerForElementAndIdentifier(element, "poetry--core--checked")
  }
}
