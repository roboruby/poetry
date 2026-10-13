import { Controller } from "@hotwired/stimulus"

/**
 * Marquee: the loop itself is CSS (the motion stylesheet), so this
 * controller never loads the engine. It owns the pause control: a toggle
 * that holds the loop still, mirrored to data-paused on the marquee and
 * aria-pressed on the button. Hover and focus inside pause it too, in CSS.
 */
export default class MarqueeController extends Controller {
  static targets = ["pause"]

  static values = {
    // Whether the loop is held still by the pause control.
    paused: { type: Boolean, default: false }
  }

  /**
   * Pauses a running loop or resumes a paused one.
   *
   * @returns {void}
   */
  toggle() {
    this.pausedValue = !this.pausedValue
  }

  /**
   * Mirrors the paused state to the marquee and the control.
   *
   * @param {boolean} paused
   * @returns {void}
   */
  pausedValueChanged(paused) {
    this.element.toggleAttribute("data-paused", paused)
    if (this.hasPauseTarget) this.pauseTarget.setAttribute("aria-pressed", String(paused))
  }
}
