import { Controller } from "@hotwired/stimulus"
import { teardown, scopeOf } from "@poetry/controllers/helpers/scope"
import { useBeforeCache } from "@poetry/controllers/behaviors/before_cache"
import { useScrollValue } from "@poetry/motion/behaviors/scroll_value"

/**
 * Scroll progress: a bar that fills as the reader scrolls the page, or
 * one element (target-id). The controller writes --scroll-progress (0 to
 * 1); the motion stylesheet scales the bar. It is feedback on the reader's
 * own scrolling, so it keeps following under reduced motion. The bar is
 * decorative; the server renders it empty, and teardown and the Turbo
 * cache empty it again.
 */
export default class ScrollProgressController extends Controller {
  static values = {
    // The id of the element whose scroll the bar follows; the page when blank.
    targetId: String
  }

  /**
   * Starts following the scroll.
   *
   * @returns {void}
   */
  connect() {
    const clear = () => this.element.style.removeProperty("--scroll-progress")
    const target = this.targetIdValue ? document.getElementById(this.targetIdValue) : null
    const options = target ? { target, offset: ["start start", "end end"], follow: true } : { follow: true }
    useScrollValue(this, (progress) => this.element.style.setProperty("--scroll-progress", String(progress)), options)
    useBeforeCache(this, clear)
    scopeOf(this).defer(clear)
  }

  /**
   * Stops following and empties the bar.
   *
   * @returns {void}
   */
  disconnect() {
    teardown(this)
  }
}
