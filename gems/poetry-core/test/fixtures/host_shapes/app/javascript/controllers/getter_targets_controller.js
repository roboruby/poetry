import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static get targets() { return ["a", "b"] }
  static get values() { return { count: Number } }
  pulse() {}
}
