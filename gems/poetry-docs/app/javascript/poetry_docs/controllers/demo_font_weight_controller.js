import { Controller } from "@hotwired/stimulus"

// Docs demo harness - NOT part of poetry. The font-weight selector's
// live readout: poetry:toggle-group:change carries value (single type);
// the <code> in the field hint follows it.
export default class extends Controller {
  static targets = ["readout"]

  update(event) {
    const value = event.detail.value
    if (value) this.readoutTarget.textContent = `font-${value}`
  }
}
