import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]
  static values = { url: String }

  submit(event) {
    event.preventDefault()
  }
}
