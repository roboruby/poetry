import { Controller } from "@hotwired/stimulus"

// Docs demo harness - NOT part of poetry. Six buttons, six viewport
// toaster regions: show() clones the template for the pressed position
// into its matching toaster (the same append a turbo_stream.poetry_toast
// does); the toast's own duration handles dismissal.
export default class extends Controller {
  static targets = ["toaster", "template"]

  show(event) {
    const position = event.params.position
    const toaster = this.toasterTargets.find((el) => el.dataset.position === position)
    const template = this.templateTargets.find((el) => el.dataset.position === position)
    if (toaster && template) toaster.append(template.content.cloneNode(true))
  }
}
