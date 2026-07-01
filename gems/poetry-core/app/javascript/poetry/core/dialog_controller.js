import { Controller } from "@hotwired/stimulus"
import { setState } from "@poetry/controllers/helpers/state"

// The native-dialog primitive: borrow the PLATFORM overlay -
// showModal() gives the focus trap, Esc handling, top-layer stacking, and
// focus return for free; this controller adds what the platform doesn't:
// data-state for CSS variants, backdrop-click dismissal, and a body
// scroll-lock. Consumed by Dialog (and later AlertDialog / Sheet).
export default class extends Controller {
  static targets = ["dialog"]
  static values = {
    // Set false for AlertDialog-style confirmations: backdrop clicks stop dismissing.
    dismissible: { type: Boolean, default: true }
  }

  disconnect() {
    this.unlockScroll()
  }

  open() {
    this.dialogTarget.showModal()
    setState(this.dialogTarget, "open")
    this.lockScroll()
  }

  close(event) {
    if (event?.type === "cancel") event.preventDefault() // route Esc through close() so state stays in sync
    this.dialogTarget.close()
    setState(this.dialogTarget, "closed")
    this.unlockScroll()
  }

  // A click on the <dialog> element itself (not its children) is a
  // backdrop click - the native element receives it because the backdrop
  // is rendered by the dialog.
  backdropClose(event) {
    if (!this.dismissibleValue) return
    if (event.target === this.dialogTarget) this.close()
  }

  lockScroll() {
    this.previousOverflow = document.body.style.overflow
    document.body.style.overflow = "hidden"
  }

  unlockScroll() {
    if (this.previousOverflow === undefined) return

    document.body.style.overflow = this.previousOverflow
    this.previousOverflow = undefined
  }
}
