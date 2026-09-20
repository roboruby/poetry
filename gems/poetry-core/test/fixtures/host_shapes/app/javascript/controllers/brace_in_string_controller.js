import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  before() {
    return this.element.textContent.replace("{", "")
  }
  after() {}
}
