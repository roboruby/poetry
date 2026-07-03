import { Controller } from "@hotwired/stimulus"
import { setState } from "@poetry/controllers/helpers/state"

// The Toggle micro-machine (the smallest controller in the suite): flip
// aria-pressed and mirror data-state=on|off - WRITTEN TOGETHER, never
// separately. The DOM is the store: no Values, no internal state. This is
// deliberately NOT poetry--core--checked (different ARIA vocabulary, no
// input to sync) and not poetry--core--state (that owns aria-expanded
// disclosure) - three micro-controllers, three vocabularies.
//
// No keydown code: Space AND Enter both activate a native button (click) -
// Radix-exact (its Toggle has no keyboard handlers at all).
//
// poetry:toggle:change is CANCELABLE and fires BEFORE the flip renders:
// preventDefault vetoes it (hosts that must confirm). The pressed value in
// the detail is the state the toggle is ABOUT to enter.
export default class PressedController extends Controller {
  static values = {}

  toggle() {
    if (this.#disabled()) return

    this.#commit(this.element.getAttribute("aria-pressed") !== "true")
  }

  // --- the programmatic controllable-state surface (the rollback recipe:
  // hosts revert a failed effect via set(false)) ---

  press() {
    this.set(true)
  }

  unpress() {
    this.set(false)
  }

  set(pressed) {
    if (this.#disabled()) return

    this.#commit(Boolean(pressed))
  }

  #commit(pressed) {
    const change = this.dispatch("change", {
      prefix: "poetry:toggle",
      cancelable: true,
      detail: { pressed }
    })

    if (change.defaultPrevented) return

    this.element.setAttribute("aria-pressed", String(pressed))
    setState(this.element, pressed ? "on" : "off")
  }

  #disabled() {
    return this.element.hasAttribute("disabled") || this.element.getAttribute("aria-disabled") === "true"
  }
}
