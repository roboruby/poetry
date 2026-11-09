import { Controller } from "@hotwired/stimulus"
import { teardown } from "@poetry/controllers/helpers/scope"
import { usePointer } from "@poetry/motion/behaviors/pointer"
import { useSpring } from "@poetry/motion/behaviors/spring"

/**
 * Magnetic: the inner layer leans a few pixels toward a fine pointer over
 * it and springs home when the pointer leaves, through --magnet-x and
 * --magnet-y. The wrapped control never moves its hit area or its focus;
 * only the layer that draws it shifts. Touch and reduced motion leave it
 * still.
 */
export default class MagneticController extends Controller {
  static targets = ["layer"]

  static values = {
    // The farthest the layer moves, in pixels.
    strength: { type: Number, default: 8 },
    // The spring token the pull follows.
    spring: { type: String, default: "snappy" }
  }

  /**
   * Starts pulling the layer toward the pointer.
   *
   * @returns {void}
   */
  connect() {
    if (!this.hasLayerTarget) return

    const x = useSpring(this, this.layerTarget, "--magnet-x", { unit: "px", spring: this.springValue })
    const y = useSpring(this, this.layerTarget, "--magnet-y", { unit: "px", spring: this.springValue })
    usePointer(this, this.element, (position) => {
      x.set(position.x * this.strengthValue)
      y.set(position.y * this.strengthValue)
    }, { onLeave: () => { x.set(0); y.set(0) } })
  }

  /**
   * Stops the pull and puts the layer home.
   *
   * @returns {void}
   */
  disconnect() {
    teardown(this)
  }
}
