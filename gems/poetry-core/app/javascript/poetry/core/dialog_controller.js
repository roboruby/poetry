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
    dismissible: { type: Boolean, default: true },
    // OPT-IN global shortcut ("meta+k") toggling the dialog - the
    // CommandDialog ⌘K affordance (Command); shadcn
    // leaves it to a caller useEffect, poetry ships it because every
    // consumer writes the same ten lines. "meta" matches metaKey OR
    // ctrlKey (⌘K on mac, ^K elsewhere - the cmdk convention).
    hotkey: { type: String, default: "" }
  }

  #onHotkey = null

  connect() {
    if (this.hotkeyValue === "") return

    this.#onHotkey = (event) => {
      if (!this.#matchesHotkey(event)) return

      event.preventDefault()
      this.toggle()
    }
    window.addEventListener("keydown", this.#onHotkey)
  }

  disconnect() {
    this.unlockScroll()

    if (this.#onHotkey) {
      window.removeEventListener("keydown", this.#onHotkey)
      this.#onHotkey = null
    }
  }

  toggle() {
    if (this.dialogTarget.open) this.close()
    else this.open()
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

  // A backdrop click targets the <dialog> element itself AND lands outside
  // its bounding rect (the backdrop is rendered by the dialog). The target
  // check alone is not enough: clicks on the dialog's own padding / grid
  // gaps also target the element (2026-07-01 browser pass - they were
  // incorrectly dismissing).
  backdropClose(event) {
    if (!this.dismissibleValue) return
    if (event.target !== this.dialogTarget) return

    const rect = this.dialogTarget.getBoundingClientRect()
    const inside = rect.top <= event.clientY && event.clientY <= rect.bottom &&
      rect.left <= event.clientX && event.clientX <= rect.right
    if (!inside) this.close()
  }

  // "meta+k" / "ctrl+shift+p" style descriptors: '+'-separated modifiers
  // plus one final key token, matched exactly (unlisted modifiers must be
  // up, so plain typing never triggers).
  #matchesHotkey(event) {
    const tokens = this.hotkeyValue.toLowerCase().split("+").map((token) => token.trim())
    const key = tokens.pop()

    if ((event.key ?? "").toLowerCase() !== key) return false

    const meta = tokens.includes("meta") ? (event.metaKey || event.ctrlKey) : true
    const ctrl = tokens.includes("ctrl") ? event.ctrlKey : true
    const shift = tokens.includes("shift") === event.shiftKey
    const alt = tokens.includes("alt") === event.altKey
    const noStray = tokens.includes("meta") || tokens.includes("ctrl") ||
      (!event.metaKey && !event.ctrlKey)

    return meta && ctrl && shift && alt && noStray
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
