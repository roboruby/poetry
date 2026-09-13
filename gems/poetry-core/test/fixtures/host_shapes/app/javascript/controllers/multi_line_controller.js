import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static targets = [
    "a",
    "b", // the second one, "old"
  ]
  static values = {
    count: Number,
    name: { type: String, default: "x" },
    list: { type: Array, default: [1, "two"] },
    obj: { type: Object, default: { a: 1 } },
    nested: {
      type: Object,
      default: {}
    },
  }
  pulse() {}
}
