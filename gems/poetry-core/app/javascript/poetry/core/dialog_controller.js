import { Controller } from "@hotwired/stimulus"
import { setState } from "@poetry/controllers/helpers/state"
import { matchesHotkey } from "@poetry/controllers/helpers/hotkey"
import { lockScroll, unlockScroll } from "@poetry/controllers/helpers/scroll_lock"
import { onBeforeCache } from "@poetry/controllers/helpers/turbo_cache"

// The native-dialog primitive: borrow the PLATFORM overlay -
// showModal() gives the focus trap, Esc handling, top-layer stacking, and
// focus return for free; this controller adds what the platform doesn't:
// the data-open/data-closed pair for CSS variants, backdrop-click
// dismissal, and a body scroll-lock. Consumed by Dialog (and later AlertDialog / Sheet).
export default class extends Controller {
  static targets = ["dialog"]
  static values = {
    // Set false for AlertDialog-style confirmations: backdrop clicks stop dismissing.
    dismissible: { type: Boolean, default: true },
    // OPT-IN global shortcut ("meta+k") toggling the dialog - the
    // CommandDialog ⌘K affordance; shadcn
    // leaves it to a caller useEffect, poetry ships it because every
    // consumer writes the same ten lines. "meta" matches metaKey OR
    // ctrlKey (⌘K on mac, ^K elsewhere - the command-palette convention).
    hotkey: { type: String, default: "" }
  }

  #onHotkey = null
  #unsubscribeBeforeCache = null

  connect() {
    this.#healRestoredSnapshot()
    // Close before Turbo snapshots: an open dialog serialized into the
    // cache restores as a de-modalized zombie over a frozen scroll lock.
    this.#unsubscribeBeforeCache = onBeforeCache(() => {
      if (this.hasDialogTarget && this.dialogTarget.open) this.close()
    })

    if (this.hotkeyValue === "") return

    // defaultPrevented gate: two dialogs bound to the same descriptor
    // degrade to first-registered-wins instead of both toggling open.
    this.#onHotkey = (event) => {
      if (event.defaultPrevented || !this.#matchesHotkey(event)) return

      event.preventDefault()
      this.toggle()
    }
    window.addEventListener("keydown", this.#onHotkey)
  }

  disconnect() {
    this.unlockScroll()
    this.#unsubscribeBeforeCache?.()
    this.#unsubscribeBeforeCache = null

    if (this.#onHotkey) {
      window.removeEventListener("keydown", this.#onHotkey)
      this.#onHotkey = null
    }
  }

  // A dialog restored from a PRE-FIX cached snapshot: the open attribute
  // survived serialization but :modal did not, and the body's inline
  // scroll-lock styles came back with no refcount behind them. Normalize
  // to closed and clear the orphaned lock styles directly (the refcounted
  // helper is at zero on a fresh page and must not be decremented).
  #healRestoredSnapshot() {
    if (!this.hasDialogTarget) return

    const dialog = this.dialogTarget

    if (!dialog.open) return
    // A genuinely modal dialog only reconnects mid-flight when its subtree
    // is MOVED while open (the sidebar DOM-move class) - leave those alone.
    // Engines without :modal support (happy-dom) treat open-at-connect as
    // the zombie it almost certainly is.
    let modal = false
    try {
      modal = dialog.matches(":modal")
    } catch {
      modal = false
    }
    if (modal) return

    dialog.close()
    setState(dialog, "closed")
    document.body.style.overflow = ""
    document.body.style.paddingRight = ""
    document.documentElement.style.scrollbarGutter = ""
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

  // The descriptor grammar lives in helpers/hotkey.js (shared with the
  // generic hotkey controller).
  #matchesHotkey(event) {
    return matchesHotkey(event, this.hotkeyValue)
  }

  // Shared refcounted lock with scrollbar-gutter compensation - subclasses
  // (sheet/drawer/sidebar) inherit these entry points unchanged; the
  // instance flag keeps double-unlocks (disconnect after close) balanced.
  lockScroll() {
    if (this.#locked) return

    this.#locked = true
    lockScroll()
  }

  unlockScroll() {
    if (!this.#locked) return

    this.#locked = false
    unlockScroll()
  }

  #locked = false
}
