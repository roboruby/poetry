import { Controller } from "@hotwired/stimulus"
import { teardown, scopeOf } from "@poetry/controllers/helpers/scope"
import { useBeforeCache } from "@poetry/controllers/behaviors/before_cache"
import { useScrollValue } from "@poetry/motion/behaviors/scroll_value"

/**
 * Text reveal: the words brighten as the text scrolls through the
 * viewport. The server renders every word at full strength; this
 * controller writes one --reveal-progress custom property, and the motion
 * stylesheet turns it into each word's opacity. Removing it, at teardown
 * and before Turbo caches the page, shows the finished text.
 */
export default class TextRevealController extends Controller {
  /**
   * Starts the effect for this connect.
   *
   * @returns {void}
   */
  connect() {
    const clear = () => this.element.style.removeProperty("--reveal-progress")
    useScrollValue(this, (progress) => this.element.style.setProperty("--reveal-progress", String(progress)), {
      target: this.element, offset: ["start end", "center center"]
    })
    useBeforeCache(this, clear)
    scopeOf(this).defer(clear)
  }

  /**
   * Undoes everything this connect started, leaving the finished state.
   *
   * @returns {void}
   */
  disconnect() {
    teardown(this)
  }
}
