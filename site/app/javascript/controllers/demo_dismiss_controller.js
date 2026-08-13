import { Controller } from "@hotwired/stimulus"

// Docs-only harness (NOT part of poetry): removes the wrapped element on
// dismiss. In an app the same click is element.remove() from your own
// controller, or a Turbo Stream remove - a dismissed alert needs no
// state machine.
export default class extends Controller {
  dismiss() {
    this.element.remove()
  }
}
