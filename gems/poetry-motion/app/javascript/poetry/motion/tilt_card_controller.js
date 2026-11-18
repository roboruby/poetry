import { Controller } from "@hotwired/stimulus"
import { teardown } from "@poetry/controllers/helpers/scope"
import { usePointer } from "@poetry/motion/behaviors/pointer"
import { useSpring } from "@poetry/motion/behaviors/spring"

/**
 * Tilt card: the inner layer leans toward a fine pointer and springs back
 * flat when it leaves. Two custom properties, --tilt-x and --tilt-y, carry
 * the angles; the motion stylesheet rotates the layer, never the outer
 * element. Touch, coarse pointers and reduced motion leave it flat.
 */
export default class TiltCardController extends Controller {
  static targets = ["layer"]

  static values = {
    // The largest lean, in degrees.
    max: { type: Number, default: 8 },
    // The spring token the lean follows.
    spring: { type: String, default: "snappy" },
    // false leaves the card flat.
    animate: { type: Boolean, default: true }
  }

  /**
   * Starts the effect for this connect.
   *
   * @returns {void}
   */
  connect() {
    if (!this.animateValue || !this.hasLayerTarget) return

    const x = useSpring(this, this.layerTarget, "--tilt-x", { unit: "deg", spring: this.springValue })
    const y = useSpring(this, this.layerTarget, "--tilt-y", { unit: "deg", spring: this.springValue })
    usePointer(this, this.element, (position) => {
      x.set(position.x * this.maxValue)
      y.set(-position.y * this.maxValue)
    }, { onLeave: () => { x.set(0); y.set(0) } })
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
