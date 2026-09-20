import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static targets = ["a", "b"]
  static classes = ['x', "y",]
  static outlets = ["other"]
  pulse() {}
}
