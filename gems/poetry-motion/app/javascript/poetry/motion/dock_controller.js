import { Controller } from "@hotwired/stimulus"
import { teardown, scopeOf } from "@poetry/controllers/helpers/scope"
import { useSpring } from "@poetry/motion/behaviors/spring"
import { prefersReducedMotion } from "@poetry/motion/policy"

/**
 * Dock: the items nearest a fine pointer swell, each by how close it is,
 * and settle back when the pointer leaves - the magnifying launcher. Each
 * item springs its own --dock-scale; the motion stylesheet scales it from
 * the edge the dock sits on, so the layout never reflows. Touch, coarse
 * pointers and reduced motion leave the items still.
 */
export default class DockController extends Controller {
  static values = {
    // The scale of the item right under the pointer.
    magnification: { type: Number, default: 1.5 },
    // How far, in pixels, the swell reaches from the pointer.
    distance: { type: Number, default: 120 },
    // The spring token the items follow.
    spring: { type: String, default: "snappy" }
  }

  /**
   * Starts swelling the items toward the pointer.
   *
   * @returns {void}
   */
  connect() {
    const coarse = typeof window.matchMedia === "function" && window.matchMedia("(pointer: coarse)").matches
    if (prefersReducedMotion() || coarse) return

    const scope = scopeOf(this)
    const items = [...this.element.children]
    const scales = items.map((item) => useSpring(this, item, "--dock-scale", { spring: this.springValue }))
    const vertical = this.element.dataset.orientation === "vertical"
    scope.listen(this.element, "pointermove", (event) => {
      if (event.pointerType === "touch" || prefersReducedMotion()) return
      items.forEach((item, index) => {
        const rect = item.getBoundingClientRect()
        const center = vertical ? rect.top + rect.height / 2 : rect.left + rect.width / 2
        const away = Math.abs((vertical ? event.clientY : event.clientX) - center)
        scales[index].set(1 + (this.magnificationValue - 1) * Math.max(0, 1 - away / this.distanceValue))
      })
    })
    scope.listen(this.element, "pointerleave", () => scales.forEach((scale) => scale.set(1)))
  }

  /**
   * Stops swelling and settles every item.
   *
   * @returns {void}
   */
  disconnect() {
    teardown(this)
  }
}
