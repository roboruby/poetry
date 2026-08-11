import { Controller } from "@hotwired/stimulus"

// Docs demo harness - NOT part of poetry. The controlled-progress story:
// a Slider drives the Progress bar the way app state would - the input
// event updates the indicator width, the aria value, and the readout.
export default class extends Controller {
  static targets = ["progress"]

  update(event) {
    // poetry:slider:change carries detail.value (an array of thumb values).
    const value = Number(event.detail.value[0])
    const root = this.progressTarget
    const max = Number(root.getAttribute("aria-valuemax")) || 100
    const percent = Math.round((value / max) * 100)

    root.setAttribute("aria-valuenow", String(value))
    const indicator = root.querySelector("[data-slot=progress-indicator]")
    if (indicator) indicator.style.width = `${percent}%`
    const readout = root.querySelector("[data-slot=progress-value]")
    if (readout) readout.textContent = `${percent}%`
  }
}
