import { Controller } from "@hotwired/stimulus"

// Docs-only harness (NOT part of poetry): mirrors the slider's live
// value into a readout span via the poetry:slider:change event.
export default class extends Controller {
  static targets = ["output"]

  update(event) {
    this.outputTarget.textContent = event.detail.value.join(", ")
  }
}
