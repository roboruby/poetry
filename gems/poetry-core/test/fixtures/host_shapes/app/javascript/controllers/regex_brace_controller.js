import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  before() {
    return /\{/.test(this.element.id)
  }
  after() {}
}
