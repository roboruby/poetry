import { Controller } from "@hotwired/stimulus"
import { teardown, scopeOf } from "@poetry/controllers/helpers/scope"
import { useMeasure } from "@poetry/controllers/behaviors/measure"
import { useAnimate } from "@poetry/motion/behaviors/animate"
import { prefersReducedMotion } from "@poetry/motion/policy"

/**
 * Layout group: elements that share a data-layout-id are one thing in
 * different places, an active-tab indicator or a selected-item highlight.
 * When the visible one changes (a class, an attribute or a child changes
 * inside the group), the new one animates from where the old one was to
 * where it is, by translate and scale, and ends at its own style. The
 * group remembers each id's last box relative to itself, so scrolling
 * between changes does not throw the move off.
 */
export default class LayoutGroupController extends Controller {
  static values = {
    // Milliseconds for each move.
    duration: { type: Number, default: 300 }
  }

  /**
   * Records the visible boxes and starts watching the group.
   *
   * @returns {void}
   */
  connect() {
    this.boxes = new Map()
    this.#record()
    useMeasure(this, this.element, () => this.#record())
    const observer = new MutationObserver(() => this.#moved())
    observer.observe(this.element, { subtree: true, childList: true, attributes: true,
      attributeFilter: ["class", "hidden", "aria-checked", "aria-selected", "aria-pressed", "aria-current",
        "data-state", "data-active", "data-layout-id"] })
    scopeOf(this).defer(() => observer.disconnect())
  }

  /**
   * Stops watching and returns the moving elements to their own style.
   *
   * @returns {void}
   */
  disconnect() {
    teardown(this)
  }

  // The visible element for each layout id, with its box relative to the group.
  #visible() {
    const origin = this.element.getBoundingClientRect()
    const found = new Map()
    for (const element of this.element.querySelectorAll("[data-layout-id]")) {
      const rect = element.getBoundingClientRect()
      if (rect.width === 0 && rect.height === 0) continue
      found.set(element.dataset.layoutId, {
        element, left: rect.left - origin.left, top: rect.top - origin.top, width: rect.width, height: rect.height
      })
    }
    return found
  }

  #record() {
    this.boxes = this.#visible()
  }

  // Animates each id whose visible element changed from its old box.
  #moved() {
    const now = this.#visible()
    for (const [id, box] of now) {
      const before = this.boxes.get(id)
      if (!before || before.element === box.element || prefersReducedMotion()) continue
      const dx = before.left - box.left
      const dy = before.top - box.top
      const sx = box.width ? before.width / box.width : 1
      const sy = box.height ? before.height / box.height : 1
      useAnimate(this, box.element, {
        transformOrigin: ["0 0", "0 0"], translate: [`${dx}px ${dy}px`, "0px 0px"], scale: [`${sx} ${sy}`, "1 1"]
      }, { duration: this.durationValue })
    }
    this.boxes = now
  }
}
