import { Controller } from "@hotwired/stimulus"
import { announce } from "@poetry/controllers/helpers/announce"
import { exitPresence } from "@poetry/controllers/helpers/presence"
import { setState, stateOf } from "@poetry/controllers/helpers/state"

// One toast item (poetry's own Toast - the sonner SLOT on Radix-Toast a11y
// semantics). The item is role=status aria-live=off: it never announces
// itself - on connect it speaks ONCE through the announce singleton at its
// politeness (destructive -> assertive, wired server-side via the
// politeness value). The auto-dismiss timer follows APG/WCAG 2.2.1 timing:
// it PAUSES on hover, focus-within, window blur and tab-hidden (reasons are
// refcounted so overlapping pauses cannot resume early), and duration <= 0
// means persistent (required for undo/action toasts). Dismiss flips
// data-open -> data-closed, dispatches poetry:toast:dismiss {id, reason} (the
// toaster's reflow + focus-return seam), then presence holds the node until
// its exit animation finishes before removal.
//
// Swipe-to-dismiss is a browser-verification-GATED enhancement (contract) -
// it does not ship in this pass; the swipe reason is reserved.
const EVENT_PREFIX = "poetry:toast"

const ACTION_SELECTOR = '[data-slot="toast-action"]'
const TITLE_SELECTOR = '[data-slot="toast-title"]'
const DESCRIPTION_SELECTOR = '[data-slot="toast-description"]'

// event.type -> pause/resume reason, so each pause source releases only
// its own hold (hover out must not resume a focus hold).
const PAUSE_REASONS = {
  mouseenter: "hover",
  mouseleave: "hover",
  focusin: "focus",
  focusout: "focus"
}

let toastSequence = 0

export default class ToastController extends Controller {
  static targets = ["action", "close"]
  static values = {
    duration: { type: Number, default: 5000 },
    politeness: { type: String, default: "polite" }
  }

  #wired = []
  #timer = null
  #remaining = 0
  #startedAt = null
  #pauseReasons = new Set()
  #dismissed = false
  #onVisibilityChange = () => {
    if (document.hidden) this.pause("visibility")
    else this.resume("visibility")
  }
  #onWindowBlur = () => this.pause("window")
  #onWindowFocus = () => this.resume("window")

  connect() {
    if (!this.element.id) this.element.id = `poetry-toast-${(toastSequence += 1).toString(16)}`
    if (!stateOf(this.element)) setState(this.element, "open")

    // Announce ONCE through the singleton (the item is aria-live=off).
    // Consumers must never announce() toast content themselves.
    announce(this.#message(), this.politenessValue)

    // APG timing: pause while the tab is hidden or the window is blurred.
    this.#listen(document, "visibilitychange", this.#onVisibilityChange)
    this.#listen(window, "blur", this.#onWindowBlur)
    this.#listen(window, "focus", this.#onWindowFocus)
    // Esc while focus is inside dismisses this toast.
    this.#listen(this.element, "keydown", (event) => {
      if (event.key !== "Escape") return

      event.stopPropagation()
      this.dismiss("close")
    })

    this.#remaining = this.durationValue

    // A toast queued by the toaster (hidden at connect) holds its timer
    // until promotion; the toaster resumes it with the "queued" reason.
    if (this.element.hidden) this.#pauseReasons.add("queued")
    if (document.hidden) this.#pauseReasons.add("visibility")

    this.#startTimer()

    this.dispatch("show", {
      prefix: EVENT_PREFIX,
      detail: { id: this.element.id, variant: this.element.dataset.variant ?? "default" }
    })
  }

  disconnect() {
    this.#stopTimer()

    for (const [target, type, listener] of this.#wired) target.removeEventListener(type, listener)

    this.#wired = []
    this.#pauseReasons.clear()
  }

  // --- timer pause/resume (markup: mouseenter/focusin -> pause,
  //     mouseleave/focusout -> resume; the toaster + window paths call with
  //     string reasons) ---

  pause(eventOrReason) {
    this.#pauseReasons.add(this.#reasonFor(eventOrReason))
    this.#stopTimer()
  }

  resume(eventOrReason) {
    this.#pauseReasons.delete(this.#reasonFor(eventOrReason))
    this.#startTimer()
  }

  // --- dismissal ---

  // Reasons: timeout | close | action | swipe(reserved) | programmatic.
  // A click on the action slot reports "action"; the close button "close".
  dismiss(eventOrReason) {
    if (this.#dismissed) return

    this.#dismissed = true
    this.#stopTimer()
    this.#pauseReasons.clear()

    const reason = typeof eventOrReason === "string"
      ? eventOrReason
      : this.#reasonFromEvent(eventOrReason)

    // Dispatched BEFORE removal so it bubbles to the toaster (reflow +
    // focus return); presence then holds the node through its exit.
    this.dispatch("dismiss", {
      prefix: EVENT_PREFIX,
      detail: { id: this.element.id, reason }
    })

    exitPresence(this.element, { onRemove: () => this.element.remove() })
  }

  // --- internals ---

  #startTimer() {
    if (this.#timer !== null || this.#dismissed) return
    if (this.#pauseReasons.size > 0) return
    if (this.durationValue <= 0) return // persistent (undo toasts)
    if (this.#remaining <= 0) return

    this.#startedAt = Date.now()
    this.#timer = window.setTimeout(() => {
      this.#timer = null
      this.dismiss("timeout")
    }, this.#remaining)
  }

  #stopTimer() {
    if (this.#timer === null) return

    window.clearTimeout(this.#timer)
    this.#timer = null
    this.#remaining = Math.max(0, this.#remaining - (Date.now() - this.#startedAt))
    this.#startedAt = null
  }

  #reasonFor(eventOrReason) {
    if (typeof eventOrReason === "string") return eventOrReason
    if (eventOrReason?.type) return PAUSE_REASONS[eventOrReason.type] ?? eventOrReason.type

    return "manual"
  }

  #reasonFromEvent(event) {
    const origin = event?.currentTarget instanceof Element ? event.currentTarget : event?.target

    if (origin instanceof Element && origin.closest(ACTION_SELECTOR)) return "action"

    return "close"
  }

  // Title + description text, the announced payload (textContent only -
  // the singleton never sees markup).
  #message() {
    const title = this.element.querySelector(TITLE_SELECTOR)?.textContent?.trim() ?? ""
    const description = this.element.querySelector(DESCRIPTION_SELECTOR)?.textContent?.trim() ?? ""

    return [title, description].filter(Boolean).join(" ")
  }

  #listen(target, type, listener) {
    target.addEventListener(type, listener)
    this.#wired.push([target, type, listener])
  }
}
