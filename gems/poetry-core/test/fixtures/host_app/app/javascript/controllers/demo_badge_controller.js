import { Controller } from "@hotwired/stimulus"

// The dummy host's own controller: every static shape the reader covers.
export default class extends Controller {
  static targets = ["label", "count"]
  static values = {
    tone: String,
    limit: { type: Number, default: 3 },
    open: { type: Boolean, default: false },
    tags: { type: Array, default: [] }
  }
  static classes = ["active"]
  static events = ["demo:badge:pulse"]

  connect() {
    this.#tick()
  }

  disconnect() {
  }

  pulse(event) {
    if (event) {
      this.dispatch("pulse")
    }
    return this.labelTarget
  }

  async refresh() {
    await Promise.resolve()
  }

  get loud() {
    return this.toneValue === "loud"
  }

  #tick() {
    for (const target of this.countTargets) {
      target.textContent = "1"
    }
  }
}
