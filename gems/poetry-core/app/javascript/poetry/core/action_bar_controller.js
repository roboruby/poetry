import { Controller } from "@hotwired/stimulus"
import { announce } from "@poetry/controllers/helpers/announce"
import { isImeKeydown } from "@poetry/controllers/helpers/escape"

// The floating bulk-actions bar (the ActionBar contract): shows
// while its table's selection is non-empty, and holds the contract rules -
// focus NEVER moves in on show; if focus was inside when the bar hides,
// it returns to where it was before entering (the FocusScope restoreFocus
// equivalent, scoped small); "Actions available." is announced ONCE per
// appearance; the visible count RETAINS its last non-zero value while the
// bar animates out (never a "None selected" flash); Escape anywhere
// inside clears the selection (the table's engine listens for
// poetry:data-table:clear-selection bubbling up their shared wrapper).
const EVENT_PREFIX = "poetry:action-bar"

export default class ActionBarController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry:data-table:clear-selection"]

  static targets = ["count"]
  static values = {
    label: { type: String, default: "%{count} selected" }
  }

  #announced = false
  #focusBefore = null
  #onSelectionChange = (event) => this.#update(event.detail)
  #onFocusin = (event) => {
    if (!this.element.contains(event.target)) return
    if (this.element.contains(this.#focusBefore)) return

    this.#focusBefore = event.relatedTarget instanceof HTMLElement ? event.relatedTarget : null
  }

  connect() {
    // The bar and its table share a wrapper; listen there so the pairing
    // is positional, never an id contract.
    this.element.parentElement?.addEventListener(
      "poetry:data-table:selection-change", this.#onSelectionChange
    )
    document.addEventListener("focusin", this.#onFocusin)
  }

  disconnect() {
    this.element.parentElement?.removeEventListener(
      "poetry:data-table:selection-change", this.#onSelectionChange
    )
    document.removeEventListener("focusin", this.#onFocusin)
  }

  // keydown (data-action): Escape anywhere inside clears the selection.
  keydown(event) {
    if (event.key !== "Escape" || isImeKeydown(event)) return

    event.preventDefault()
    event.stopPropagation()
    this.clear()
  }

  // The clear affordance (and Escape): the table's engine owns the state.
  clear() {
    this.dispatch("clear-selection", { prefix: "poetry:data-table" })
  }

  #update({ count }) {
    const open = count > 0

    if (open) {
      // Retain-on-exit: only NON-ZERO counts ever render.
      if (this.hasCountTarget) {
        this.countTarget.textContent = this.labelValue.replace("%{count}", String(count))
      }

      if (this.element.hidden) {
        this.element.hidden = false

        if (!this.#announced) {
          announce(this.element.getAttribute("data-available-label") || "Actions available.")
          this.#announced = true
        }
      }

      this.element.setAttribute("data-open", "")
      return
    }

    this.#announced = false
    this.element.removeAttribute("data-open")
    this.element.hidden = true

    // Focus never moved IN on show; but if the user tabbed in and the bar
    // just vanished under them, put focus back where it was.
    if (this.element.contains(document.activeElement) && this.#focusBefore?.isConnected) {
      this.#focusBefore.focus()
    }

    this.#focusBefore = null
  }
}
