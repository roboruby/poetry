import { Controller } from "@hotwired/stimulus"
import { acquire, release } from "@poetry/controllers/helpers/announce"
import { stateOf } from "@poetry/controllers/helpers/state"

// The toast viewport (one per page): the labeled role=region <ol> that is
// the Turbo Stream append target (id=poetry-toaster, data-turbo-permanent).
// It ACQUIRES the announce singleton for its lifetime (items announce
// through it on connect), owns the F8 hotkey (focus moves to the most
// recent toast; the prior focus is remembered so dismissal returns it),
// enforces the visible LIMIT (default 3 - the oldest overflow toasts queue
// hidden with their timers held, promoted as newer ones dismiss), and owns
// the stack reflow (--poetry-toast-index, newest = 0, for the offset/scale
// stack styling).
//
// Items arrive by server render, Turbo Stream append, or poetry.toast();
// a childList MutationObserver reconciles limit + reflow on every change,
// so no append path needs to know about the toaster.
const TOAST_SELECTOR = '[data-slot="toast"]'
const TOAST_IDENTIFIER = "poetry--core--toast"

const INDEX_PROPERTY = "--poetry-toast-index"

export default class ToasterController extends Controller {
  static targets = ["item"]
  static values = {
    hotkey: { type: String, default: "F8" },
    limit: { type: Number, default: 3 },
    position: String
  }

  #observer = null
  #returnFocusTo = null
  #onKeydown = (event) => this.focusRegion(event)
  #onDismiss = (event) => this.#handleDismiss(event)

  connect() {
    acquire() // the singleton lives while a toaster is connected

    window.addEventListener("keydown", this.#onKeydown)
    this.element.addEventListener("poetry:toast:dismiss", this.#onDismiss)

    this.#observer = new MutationObserver(() => this.#reconcile())
    this.#observer.observe(this.element, { childList: true })

    this.#reconcile()
  }

  disconnect() {
    this.#observer?.disconnect()
    this.#observer = null
    window.removeEventListener("keydown", this.#onKeydown)
    this.element.removeEventListener("poetry:toast:dismiss", this.#onDismiss)
    this.#returnFocusTo = null
    release()
  }

  // The hotkey (F8 default, configurable): move focus into the region -
  // onto the most recent visible toast, else the region itself. The prior
  // focus is remembered for the dismiss return.
  focusRegion(event) {
    if (event instanceof KeyboardEvent) {
      if (event.key !== this.hotkeyValue) return

      event.preventDefault()
    }

    const active = document.activeElement

    if (active instanceof HTMLElement && !this.element.contains(active)) {
      this.#returnFocusTo = active
    }

    const target = this.#visibleToasts().at(-1) ?? this.element

    target.focus()
  }

  // Stack reflow: newest toast = index 0 (the front of the stack).
  reflow() {
    const visible = this.#visibleToasts()

    visible.forEach((toast, index) => {
      toast.style.setProperty(INDEX_PROPERTY, String(visible.length - 1 - index))
    })
  }

  // --- internals ---

  // Limit + queue + reflow, run on every childList change: the newest
  // `limit` open toasts are visible; older overflow queues hidden (timer
  // held via the toast controller's "queued" pause) until slots free up.
  #reconcile() {
    const open = this.#openToasts()
    const overflow = Math.max(0, open.length - this.limitValue)

    open.forEach((toast, index) => {
      if (index < overflow) this.#queue(toast)
      else this.#promote(toast)
    })

    this.reflow()
    this.#restoreFocusIfLost()
  }

  #queue(toast) {
    if (toast.hasAttribute("data-queued")) return

    toast.setAttribute("data-queued", "")
    toast.hidden = true
    this.#toastController(toast)?.pause("queued")
  }

  #promote(toast) {
    if (!toast.hasAttribute("data-queued")) return

    toast.removeAttribute("data-queued")
    toast.hidden = false
    this.#toastController(toast)?.resume("queued")
  }

  // Dismissal focus return: when the dismissed toast held focus (hotkey
  // entry), focus goes back to the remembered prior element.
  #handleDismiss(event) {
    const toast = event.target instanceof Element ? event.target.closest(TOAST_SELECTOR) : null

    if (toast?.contains(document.activeElement) && this.#returnFocusTo?.isConnected) {
      this.#returnFocusTo.focus()
      this.#returnFocusTo = null
    }
  }

  // A removed toast that carried focus drops it on <body>; hand it back.
  #restoreFocusIfLost() {
    if (document.activeElement !== document.body) return
    if (!this.#returnFocusTo?.isConnected) return

    this.#returnFocusTo.focus()
    this.#returnFocusTo = null
  }

  #toasts() {
    return Array.from(this.element.querySelectorAll(TOAST_SELECTOR))
  }

  #openToasts() {
    return this.#toasts().filter((toast) => stateOf(toast) !== "closed")
  }

  #visibleToasts() {
    return this.#openToasts().filter((toast) => !toast.hidden)
  }

  #toastController(toast) {
    return this.application.getControllerForElementAndIdentifier(toast, TOAST_IDENTIFIER)
  }
}
