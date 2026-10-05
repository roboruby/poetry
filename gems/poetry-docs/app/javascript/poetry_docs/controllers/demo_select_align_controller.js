import { Controller } from "@hotwired/stimulus"

// Docs-only harness (NOT part of poetry): flips the select's
// align-item-with-trigger Stimulus value from the switch so the docs
// can demonstrate both placements live. In an app the option is
// server-rendered (align_item_with_trigger: true) and never toggled.
export default class extends Controller {
  static targets = ["select"]

  toggle(event) {
    this.selectTarget.setAttribute(
      "data-poetry--core--select-align-item-with-trigger-value",
      event.target.checked ? "true" : "false"
    )
  }
}
