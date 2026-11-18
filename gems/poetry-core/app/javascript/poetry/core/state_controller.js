import { Controller } from "@hotwired/stimulus"
import { setState, stateOf } from "@poetry/controllers/helpers/state"
import { enterPresence, exitPresence, presenceMotionMs } from "@poetry/controllers/helpers/presence"

// Base UI's Collapsible.Panel size vars. A CSS transition cannot run to or
// from auto, so the panel's measured size rides them while it opens or
// closes, and they return to auto at rest: content that grows after the
// open is never clipped.
const PANEL_HEIGHT = "--collapsible-panel-height"
const PANEL_WIDTH = "--collapsible-panel-width"

/**
 * The controllable-state controller: seeds the data-open/
 * data-closed pair from a Value default when no other layer owns it, and
 * exposes toggle/open/close actions. "Controlled vs uncontrolled" is just which layer wrote the
 * attribute - a server re-render, the URL, an Outlet, or this default -
 * the controller code is identical either way.
 *
 * Optional reflection targets (the Collapsible contract): a trigger
 * target mirrors aria-expanded; a content target rides the presence
 * helper (the pair flip deferred through animationend, hidden applied
 * only after the exit animation finishes) and carries the measured
 * --collapsible-panel-height / --collapsible-panel-width while it opens
 * or closes (auto at rest), so a height transition can animate it.
 */
export default class extends Controller {
  static targets = ["trigger", "content"]
  static values = {
    // The state seeded on the element when it carries none: open or closed.
    state: { type: String, default: "closed" }
  }

  /**
   * Seeds the pair from the Value default when no other layer wrote it,
   * then reflects the current state onto the optional targets.
   */
  connect() {
    if (!stateOf(this.element)) setState(this.element, this.stateValue)
    if (this.hasContentTarget) this.#rest(this.contentTarget) // a restored snapshot may carry a mid-flight size
    this.#reflect(stateOf(this.element))
  }

  /** Abandons any exit animation still holding the content. */
  disconnect() {
    this.#cancelExit?.()
    this.#cancelRest?.()
  }

  /** The toggle action: open when closed, close when open. */
  toggle() {
    stateOf(this.element) === "open" ? this.close() : this.open()
  }

  /**
   * Opens: flips the pair, unhides the content target (when present),
   * measures it into the size vars and runs its entry presence, then
   * returns the vars to auto once the entry settles; mirrors
   * aria-expanded onto the trigger.
   */
  open() {
    setState(this.element, "open")
    this.#cancelExit?.()
    this.#cancelExit = null
    if (this.hasContentTarget) {
      const content = this.contentTarget
      const fresh = content.hidden

      // The starting style goes on while the panel is still display:none,
      // so the measure's style flush computes it as the FIRST value. Put on
      // after the flush, a visible panel would transition toward it.
      if (fresh) content.setAttribute("data-starting-style", "")
      content.hidden = false
      this.#measure(content)
      enterPresence(content)
      // An open that interrupts an exit runs on from where the panel is.
      if (!fresh) content.removeAttribute("data-starting-style")
      this.#restWhenSettled(content)
    }
    this.#reflect("open")
  }

  /**
   * Closes: flips the pair and holds the content target through its exit
   * animation before hiding it (the presence contract), the exit starting
   * from the measured size.
   */
  close() {
    setState(this.element, "closed")
    if (this.hasContentTarget) {
      const content = this.contentTarget

      this.#cancelRest?.()
      this.#measure(content)
      // Flush the measured size into the computed style first: otherwise
      // the transition starts from auto and the panel snaps shut.
      void content.offsetHeight
      this.#cancelExit = exitPresence(content, {
        onRemove: () => {
          content.hidden = true
          this.#cancelExit = null
          this.#rest(content)
        }
      })
    }
    this.#reflect("closed")
  }

  #cancelExit
  #cancelRest

  /**
   * Writes the panel's scroll size into the size vars, unhiding it for
   * the read when needed.
   *
   * @param {HTMLElement} content
   */
  #measure(content) {
    const wasHidden = content.hidden

    if (wasHidden) content.hidden = false
    content.style.setProperty(PANEL_HEIGHT, `${content.scrollHeight}px`)
    content.style.setProperty(PANEL_WIDTH, `${content.scrollWidth}px`)
    if (wasHidden) content.hidden = true
  }

  /**
   * Returns the size vars to auto (the at-rest value).
   *
   * @param {HTMLElement} content
   */
  #rest(content) {
    content.style.setProperty(PANEL_HEIGHT, "auto")
    content.style.setProperty(PANEL_WIDTH, "auto")
  }

  /**
   * Rests the vars once the entry settles: on transitionend for height
   * or width (another property finishing first must not cut it short), on
   * a keyframe's animationend, or after the declared motion as a fallback.
   *
   * @param {HTMLElement} content
   */
  #restWhenSettled(content) {
    this.#cancelRest?.()

    const settle = (event) => {
      if (event?.target && event.target !== content) return
      if (event?.type === "transitionend" && !/^(height|width)$/.test(event.propertyName)) return

      this.#cancelRest?.()
      if (stateOf(this.element) === "open") this.#rest(content)
    }
    // Two frames ride data-starting-style before the transition can start.
    const timer = window.setTimeout(settle, presenceMotionMs(content) + 50)

    content.addEventListener("transitionend", settle)
    content.addEventListener("animationend", settle)
    this.#cancelRest = () => {
      content.removeEventListener("transitionend", settle)
      content.removeEventListener("animationend", settle)
      window.clearTimeout(timer)
      this.#cancelRest = null
    }
  }

  #reflect(state) {
    const open = state === "open"
    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", String(open))
      // Disclosure-trigger reflection: the trigger wears bare
      // data-panel-open while its panel is open (no CSS consumes it yet -
      // the aria-expanded selector styles the chevron).
      setState(this.triggerTarget, open ? "panel-open" : "panel-closed")
    }
    if (this.hasContentTarget && !open && !this.#cancelExit) this.contentTarget.hidden = true
  }
}
