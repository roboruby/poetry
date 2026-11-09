import { Controller } from "@hotwired/stimulus"
import { teardown } from "@poetry/controllers/helpers/scope"
import { useDrag } from "@poetry/motion/behaviors/drag"

/**
 * Draggable: the content follows a drag, within its parent's box when
 * bounded, and springs home on release unless snap-back is off. Dragging
 * is direct manipulation, so it works under reduced motion; only the
 * spring home is skipped there. The server renders the content in place,
 * which is where teardown puts it back.
 */
export default class DraggableController extends Controller {
  static values = {
    // "x" or "y" locks the drag to one axis; blank drags freely.
    axis: String,
    // Keeps the drag inside the parent's box.
    bounded: { type: Boolean, default: false },
    // Springs home on release; false leaves it where it was dropped.
    snapBack: { type: Boolean, default: true },
    // The spring token the return follows.
    spring: { type: String, default: "snappy" }
  }

  /**
   * Makes the content draggable.
   *
   * @returns {void}
   */
  connect() {
    useDrag(this, this.element, {
      axis: this.axisValue || undefined,
      spring: this.springValue,
      bounds: this.boundedValue ? () => this.#parentBounds() : undefined,
      onEnd: () => !this.snapBackValue
    })
  }

  /**
   * Stops dragging and puts the content back.
   *
   * @returns {void}
   */
  disconnect() {
    teardown(this)
  }

  // How far the content can move each way and stay inside its parent.
  #parentBounds() {
    const parent = this.element.parentElement?.getBoundingClientRect()
    const own = this.element.getBoundingClientRect()
    if (!parent) return {}
    const current = (name) => parseFloat(this.element.style.getPropertyValue(name)) || 0
    const x = current("--motion-drag-x")
    const y = current("--motion-drag-y")
    return {
      left: parent.left - (own.left - x), right: parent.right - (own.right - x),
      top: parent.top - (own.top - y), bottom: parent.bottom - (own.bottom - y)
    }
  }
}
