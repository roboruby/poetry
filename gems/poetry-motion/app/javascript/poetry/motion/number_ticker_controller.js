import { Controller } from "@hotwired/stimulus"
import { teardown, scopeOf } from "@poetry/controllers/helpers/scope"
import { useInView } from "@poetry/controllers/behaviors/in_view"
import { loadEngine } from "@poetry/motion/load_engine"
import { prefersReducedMotion, entranceAllowed, spring, track, release } from "@poetry/motion/policy"

/**
 * Number ticker: counts up to a number the server already rendered. The
 * visible digits are aria-hidden; a screen reader reads the final number
 * beside them. The count springs from `from` to `value`, formatted with
 * Intl.NumberFormat, and the server's own text comes back when it lands,
 * at teardown and before Turbo caches the page. Reduced motion, a cache
 * preview and a restore visit show the final number at once.
 */
export default class NumberTickerController extends Controller {
  static targets = ["display"]

  static values = {
    // The final number, already rendered by the server.
    value: Number,
    // Where the count starts.
    from: { type: Number, default: 0 },
    // The locale for Intl.NumberFormat; the page's when blank.
    locale: String,
    // Intl.NumberFormat options, as the server formatted the final number.
    format: Object,
    // The spring token the count follows.
    spring: { type: String, default: "gentle" },
    // When the count starts: "load" or "in_view".
    trigger: { type: String, default: "in_view" },
    // Milliseconds to wait before counting.
    delay: { type: Number, default: 0 },
    // false renders the final number with no count.
    animate: { type: Boolean, default: true }
  }

  /**
   * Starts the effect for this connect.
   *
   * @returns {void}
   */
  connect() {
    if (!this.animateValue || prefersReducedMotion() || !entranceAllowed() || !this.hasDisplayTarget) return

    if (this.triggerValue === "load") this.#count()
    else useInView(this, this.element, (inView) => { if (inView) this.#count() }, { once: true })
  }

  /**
   * Undoes everything this connect started, leaving the finished state.
   *
   * @returns {void}
   */
  disconnect() {
    teardown(this)
  }

  /**
   * Springs the visible digits from `from` to `value`.
   *
   * @returns {Promise<void>}
   */
  async #count() {
    const scope = scopeOf(this)
    const display = this.displayTarget
    const final = display.textContent
    // A whole number counts in whole numbers unless the format says otherwise.
    const digits = Number.isInteger(this.valueValue) ? { maximumFractionDigits: 0 } : {}
    const formatter = new Intl.NumberFormat(this.localeValue || undefined, { ...digits, ...this.formatValue })
    let animation = null
    let stopped = false
    scope.defer(() => {
      stopped = true
      if (animation) release(animation)
    })

    const { animate } = await loadEngine()
    if (stopped) return
    animation = track(animate(this.fromValue, this.valueValue, {
      ...spring(this.springValue),
      delay: this.delayValue / 1000,
      onUpdate: (latest) => { display.textContent = formatter.format(latest) }
    }), { finish: () => { display.textContent = final } })
    await animation.finished
    if (!stopped) display.textContent = final
  }
}
