import { Controller } from "@hotwired/stimulus"
import { setState, stateOf } from "@poetry/controllers/helpers/state"

// The controllable-state controller (Tier 0): seeds data-state from a Value
// default when no other layer owns it, and exposes toggle/open/close
// actions. "Controlled vs uncontrolled" is just which layer wrote the
// attribute - a server re-render, the URL, an Outlet, or this default -
// the controller code is identical either way.
export default class extends Controller {
  static values = { state: { type: String, default: "closed" } }

  connect() {
    if (!stateOf(this.element)) setState(this.element, this.stateValue)
  }

  toggle() {
    setState(this.element, stateOf(this.element) === "open" ? "closed" : "open")
  }

  open() {
    setState(this.element, "open")
  }

  close() {
    setState(this.element, "closed")
  }
}
