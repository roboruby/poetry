import { Controller } from "@hotwired/stimulus"
const BaseTargets = ["base"]
export default class extends Controller {
  static targets = [...BaseTargets, "x"]
  pulse() {}
}
