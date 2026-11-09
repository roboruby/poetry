import { Controller } from "@hotwired/stimulus"
import { teardown, scopeOf } from "@poetry/controllers/helpers/scope"
import { usePointer } from "@poetry/motion/behaviors/pointer"

/**
 * Spotlight card: a soft glow follows a fine pointer across the card. The
 * controller writes the pointer's position as --spotlight-x and
 * --spotlight-y and switches --spotlight-opacity on; the motion stylesheet
 * draws the glow. No engine loads. The server renders the card without a
 * glow, and touch, coarse pointers and reduced motion leave it that way.
 */
export default class SpotlightCardController extends Controller {
  /**
   * Starts following the pointer.
   *
   * @returns {void}
   */
  connect() {
    const style = this.element.style
    const clear = () => {
      for (const name of ["--spotlight-x", "--spotlight-y", "--spotlight-opacity"]) style.removeProperty(name)
    }
    usePointer(this, this.element, ({ x, y }) => {
      const { width, height } = this.element.getBoundingClientRect()
      style.setProperty("--spotlight-x", `${((x + 1) / 2) * width}px`)
      style.setProperty("--spotlight-y", `${((y + 1) / 2) * height}px`)
      style.setProperty("--spotlight-opacity", "1")
    }, { onLeave: clear })
    scopeOf(this).defer(clear)
  }

  /**
   * Stops following and clears the glow.
   *
   * @returns {void}
   */
  disconnect() {
    teardown(this)
  }
}
