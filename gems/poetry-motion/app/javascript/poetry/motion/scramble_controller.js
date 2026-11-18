import { Controller } from "@hotwired/stimulus"
import { teardown, scopeOf } from "@poetry/controllers/helpers/scope"
import { useInterval, useTimeout } from "@poetry/controllers/behaviors/interval"
import { useInView } from "@poetry/controllers/behaviors/in_view"
import { useBeforeCache } from "@poetry/controllers/behaviors/before_cache"
import { prefersReducedMotion, entranceAllowed } from "@poetry/motion/policy"

const GLYPHS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#%&*+=?"

/**
 * Scramble: the text decodes from random glyphs into itself, left to
 * right, when it comes into view. The server renders the text, a screen
 * reader reads it once, and the aria-hidden display scrambles; the text
 * comes back when it lands, at teardown and before Turbo caches the page.
 * Spaces stay spaces, so the line keeps its shape. Reduced motion, a cache
 * preview and a restore visit show the text at once.
 */
export default class ScrambleController extends Controller {
  static targets = ["display"]

  static values = {
    // Milliseconds from the first scramble to the last letter landing.
    duration: { type: Number, default: 800 },
    // Milliseconds before it starts.
    delay: { type: Number, default: 0 },
    // When it starts: "load" or "in_view".
    trigger: { type: String, default: "in_view" },
    // false shows the text with no scramble.
    animate: { type: Boolean, default: true }
  }

  /**
   * Scrambles the text when the trigger fires.
   *
   * @returns {void}
   */
  connect() {
    if (!this.animateValue || prefersReducedMotion() || !entranceAllowed() || !this.hasDisplayTarget) return

    const display = this.displayTarget
    const text = display.textContent
    const restore = () => { display.textContent = text }
    scopeOf(this).defer(restore)
    useBeforeCache(this, restore)

    const glyph = () => GLYPHS[Math.floor(Math.random() * GLYPHS.length)]
    const run = () => {
      const started = performance.now()
      const stop = useInterval(this, () => {
        const landed = Math.floor(((performance.now() - started) / this.durationValue) * text.length)
        display.textContent = [...text].map((char, index) => (index < landed || char === " " ? char : glyph())).join("")
        if (landed >= text.length) {
          stop()
          restore()
        }
      }, 30)
    }
    const start = () => (this.delayValue > 0 ? useTimeout(this, run, this.delayValue) : run())
    if (this.triggerValue === "load") start()
    else useInView(this, this.element, (inView) => { if (inView) start() }, { once: true })
  }

  /**
   * Stops scrambling and shows the text.
   *
   * @returns {void}
   */
  disconnect() {
    teardown(this)
  }
}
