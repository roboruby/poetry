import { Controller } from "@hotwired/stimulus"
import { teardown, scopeOf } from "@poetry/controllers/helpers/scope"
import { useBeforeCache } from "@poetry/controllers/behaviors/before_cache"
import { useScrollValue } from "@poetry/motion/behaviors/scroll_value"
import { prefersReducedMotion } from "@poetry/motion/policy"

/**
 * Parallax: the content drifts at its own pace as it passes through the
 * viewport, by --parallax-y. It sits where the server put it when the
 * passage is centered, which is also where teardown, the Turbo cache and
 * reduced motion leave it.
 */
export default class ParallaxController extends Controller {
  static values = {
    // Pixels of drift from entering the viewport to leaving it; negative drifts the other way.
    distance: { type: Number, default: 80 }
  }

  /**
   * Starts drifting with the scroll.
   *
   * @returns {void}
   */
  connect() {
    if (prefersReducedMotion()) return

    const style = this.element.style
    const clear = () => style.removeProperty("--parallax-y")
    useScrollValue(this, (progress) => {
      // Reduced motion switched on mid-session: rest where the server put it.
      if (prefersReducedMotion()) return clear()
      style.setProperty("--parallax-y", `${(0.5 - progress) * this.distanceValue}px`)
    }, { target: this.element, offset: ["start end", "end start"] })
    useBeforeCache(this, clear)
    scopeOf(this).defer(clear)
  }

  /**
   * Stops drifting and puts the content back.
   *
   * @returns {void}
   */
  disconnect() {
    teardown(this)
  }
}
