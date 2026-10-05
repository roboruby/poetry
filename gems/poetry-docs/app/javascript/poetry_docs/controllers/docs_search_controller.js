import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// The palette engine dispatches poetry:command:select and does nothing
// further - the host owns the consequence (the Command contract). Here
// every item's value is a page path: selecting navigates.
export default class extends Controller {
  go(event) {
    const path = event.detail.value
    if (!path?.startsWith("/")) return

    Turbo.visit(path)
  }
}
