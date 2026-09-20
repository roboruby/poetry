import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  save() { this.dispatch("saved") }
}
