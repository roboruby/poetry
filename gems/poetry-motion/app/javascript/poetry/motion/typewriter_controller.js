import { Controller } from "@hotwired/stimulus"
import { teardown, scopeOf } from "@poetry/controllers/helpers/scope"
import { useInterval, useTimeout } from "@poetry/controllers/behaviors/interval"
import { useInView } from "@poetry/controllers/behaviors/in_view"
import { useBeforeCache } from "@poetry/controllers/behaviors/before_cache"
import { prefersReducedMotion, entranceAllowed } from "@poetry/motion/policy"

/**
 * Typewriter: the server renders the whole line, and a screen reader reads
 * it once; the aria-hidden display types it out a character at a time
 * when it comes into view. The full line comes back when it is done, at
 * teardown and before Turbo caches the page. No engine loads. Reduced
 * motion, a cache preview and a restore visit show the line at once.
 */
export default class TypewriterController extends Controller {
  static targets = ["display"]

  static values = {
    // Milliseconds per character.
    speed: { type: Number, default: 50 },
    // Milliseconds before typing starts.
    delay: { type: Number, default: 0 },
    // When typing starts: "load" or "in_view".
    trigger: { type: String, default: "in_view" },
    // false shows the line with no typing.
    animate: { type: Boolean, default: true }
  }

  /**
   * Types the line when the trigger fires.
   *
   * @returns {void}
   */
  connect() {
    if (!this.animateValue || prefersReducedMotion() || !entranceAllowed() || !this.hasDisplayTarget) return

    const display = this.displayTarget
    const line = display.textContent
    const restore = () => {
      display.textContent = line
      delete this.element.dataset.typing
    }
    scopeOf(this).defer(restore)
    useBeforeCache(this, restore)

    const type = () => {
      let shown = 0
      display.textContent = ""
      this.element.dataset.typing = ""
      const stop = useInterval(this, () => {
        shown += 1
        display.textContent = line.slice(0, shown)
        if (shown >= line.length) {
          stop()
          restore()
        }
      }, this.speedValue)
    }
    const start = () => (this.delayValue > 0 ? useTimeout(this, type, this.delayValue) : type())
    if (this.triggerValue === "load") start()
    else useInView(this, this.element, (inView) => { if (inView) start() }, { once: true })
  }

  /**
   * Stops typing and shows the whole line.
   *
   * @returns {void}
   */
  disconnect() {
    teardown(this)
  }
}
