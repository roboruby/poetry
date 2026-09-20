import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static values = { open: { type: String, default: "}" }, other: Number }
  pulse() {}
}
