import { Controller } from "@hotwired/stimulus"

// The dummy host's own controller for Demo::Badge (host_controllers_test).
export default class extends Controller {
  static targets = ["label"]
  static values = { tone: { type: String, default: "neutral" } }
  static events = ["demo:badge:pulse"]

  pulse() {
    this.dispatch("pulse")
  }
}
