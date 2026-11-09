import { Controller } from "@hotwired/stimulus"
import { teardown, scopeOf } from "@poetry/controllers/helpers/scope"
import { useInterval } from "@poetry/controllers/behaviors/interval"
import { useBeforeCache } from "@poetry/controllers/behaviors/before_cache"
import { prefersReducedMotion } from "@poetry/motion/policy"

/**
 * Word rotate: the words sit stacked in one cell, the first one showing,
 * and the controller moves data-active from word to word; the motion
 * stylesheet slides them. Hover and focus pause it. It stops after its
 * rounds, back on the first word, which is also what a screen reader
 * hears and what teardown, the Turbo cache and reduced motion show.
 */
export default class WordRotateController extends Controller {
  static targets = ["word"]

  static values = {
    // Milliseconds each word shows.
    interval: { type: Number, default: 2500 },
    // How many times it goes through the words; 0 keeps going.
    rounds: { type: Number, default: 1 },
    // false leaves the first word showing.
    animate: { type: Boolean, default: true }
  }

  /**
   * Starts rotating.
   *
   * @returns {void}
   */
  connect() {
    if (!this.animateValue || prefersReducedMotion() || this.wordTargets.length < 2) return

    const scope = scopeOf(this)
    const words = this.wordTargets
    let index = 0
    let steps = 0
    let paused = false
    const show = (next) => {
      words.forEach((word, position) => word.toggleAttribute("data-active", position === next))
      index = next
    }
    const reset = () => show(0)
    scope.defer(reset)
    useBeforeCache(this, reset)
    for (const type of ["pointerenter", "focusin"]) scope.listen(this.element, type, () => { paused = true })
    for (const type of ["pointerleave", "focusout"]) scope.listen(this.element, type, () => { paused = false })

    const total = this.roundsValue > 0 ? this.roundsValue * words.length : Infinity
    const stop = useInterval(this, () => {
      if (paused || prefersReducedMotion()) return
      steps += 1
      show((index + 1) % words.length)
      if (steps >= total) stop()
    }, this.intervalValue)
  }

  /**
   * Stops rotating and shows the first word.
   *
   * @returns {void}
   */
  disconnect() {
    teardown(this)
  }
}
