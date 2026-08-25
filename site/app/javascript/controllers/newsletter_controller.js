import { Controller } from "@hotwired/stimulus"

// The landing subscribe dialog: posts the email to /subscriptions (the
// beehiiv call happens server side) and swaps the form for the confirm
// message inline. The landing page runs Turbo-free, so this owns the
// fetch + CSRF header itself.
export default class extends Controller {
  static targets = ["form", "email", "error", "success", "submit"]

  async submit(event) {
    event.preventDefault()
    this.errorTarget.hidden = true
    this.submitTarget.disabled = true

    try {
      const response = await fetch(this.formTarget.action, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: JSON.stringify({
          email: this.emailTarget.value,
          website: this.formTarget.elements.website?.value || ""
        })
      })

      const payload = await response.json()
      if (payload.ok) {
        this.formTarget.hidden = true
        this.successTarget.hidden = false
      } else {
        this.showError(payload.error)
      }
    } catch {
      this.showError()
    }
  }

  showError(message) {
    this.errorTarget.textContent = message || "We could not subscribe you. Please try again."
    this.errorTarget.hidden = false
    this.submitTarget.disabled = false
  }
}
