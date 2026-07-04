import { Controller } from "@hotwired/stimulus"
import { setState, stateOf } from "@poetry/controllers/helpers/state"
import { enterPresence, exitPresence } from "@poetry/controllers/helpers/presence"

// The controllable-state controller (Tier 0): seeds the data-open/
// data-closed pair from a Value default when no other layer owns it, and
// exposes toggle/open/close actions. "Controlled vs uncontrolled" is just which layer wrote the
// attribute - a server re-render, the URL, an Outlet, or this default -
// the controller code is identical either way.
//
// Optional reflection targets (the Collapsible contract, N2): a trigger
// target mirrors aria-expanded; a content target rides the presence
// helper (the pair flip deferred through animationend, hidden applied
// only after the exit animation finishes).
export default class extends Controller {
  static targets = ["trigger", "content"]
  static values = { state: { type: String, default: "closed" } }

  connect() {
    if (!stateOf(this.element)) setState(this.element, this.stateValue)
    this.#reflect(stateOf(this.element))
  }

  disconnect() {
    this.#cancelExit?.()
  }

  toggle() {
    stateOf(this.element) === "open" ? this.close() : this.open()
  }

  open() {
    setState(this.element, "open")
    this.#cancelExit?.()
    if (this.hasContentTarget) {
      this.contentTarget.hidden = false
      enterPresence(this.contentTarget)
    }
    this.#reflect("open")
  }

  close() {
    setState(this.element, "closed")
    if (this.hasContentTarget) {
      this.#cancelExit = exitPresence(this.contentTarget, {
        onRemove: () => {
          this.contentTarget.hidden = true
          this.#cancelExit = null
        }
      })
    }
    this.#reflect("closed")
  }

  #cancelExit

  #reflect(state) {
    const open = state === "open"
    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", String(open))
      // Base UI disclosure-trigger parity: the trigger wears bare
      // data-panel-open while its panel is open (no CSS consumes it yet -
      // the aria-expanded selector styles the chevron).
      setState(this.triggerTarget, open ? "panel-open" : "panel-closed")
    }
    if (this.hasContentTarget && !open && !this.#cancelExit) this.contentTarget.hidden = true
  }
}
