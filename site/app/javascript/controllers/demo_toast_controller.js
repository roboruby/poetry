import { Controller } from "@hotwired/stimulus"

// Docs demo harness - NOT part of poetry. The promise-toast lifecycle:
// append the loading toast, then REPLACE it in place with the settled
// one (same id) - exactly what turbo_stream.poetry_toast + a job's
// turbo_stream.replace do in a real app; a 2s timer stands in for the
// job.
export default class extends Controller {
  static targets = ["toaster", "loading", "settled"]

  disconnect() {
    if (this.timer) clearTimeout(this.timer)
  }

  create() {
    const existing = this.toasterTarget.querySelector("#promise-toast")
    if (existing) existing.remove()
    if (this.timer) clearTimeout(this.timer)

    this.toasterTarget.append(this.loadingTarget.content.cloneNode(true))
    this.timer = setTimeout(() => {
      const loading = this.toasterTarget.querySelector("#promise-toast")
      if (loading) loading.replaceWith(this.settledTarget.content.cloneNode(true))
      this.timer = null
    }, 2000)
  }
}
