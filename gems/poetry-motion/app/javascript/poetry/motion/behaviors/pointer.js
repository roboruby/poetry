// usePointer: the pointer's position over an element, from -1 to 1 on
// each axis with 0 at the center, for tilt, spotlight and magnetic
// effects. Fine pointers only: touch and coarse pointers are ignored, and
// reduced motion leaves it inert. One report per frame; onLeave fires when
// the pointer leaves, so an effect can settle back to its own style.
import { scopeOf } from "@poetry/controllers/helpers/scope"
import { prefersReducedMotion } from "@poetry/motion/policy"

/**
 * Reports pointer positions over `element` until teardown(controller).
 *
 * @param {Object} controller - the Stimulus controller instance
 * @param {HTMLElement} element - the element to track
 * @param {(position: { x: number, y: number }) => void} onMove - the handler
 * @param {{ onLeave?: () => void }} [options]
 * @returns {() => void} stops early; teardown stops it otherwise
 */
export function usePointer(controller, element, onMove, options = {}) {
  const scope = scopeOf(controller)
  const coarse = typeof window.matchMedia === "function" && window.matchMedia("(pointer: coarse)").matches
  if (prefersReducedMotion() || coarse) return () => {}

  let pending = null
  let frame = 0
  const report = () => {
    frame = 0
    if (pending) onMove(pending)
  }
  const stopListening = [
    scope.listen(element, "pointermove", (event) => {
      if (event.pointerType === "touch") return
      const rect = element.getBoundingClientRect()
      if (rect.width === 0 || rect.height === 0) return
      pending = {
        x: ((event.clientX - rect.left) / rect.width) * 2 - 1,
        y: ((event.clientY - rect.top) / rect.height) * 2 - 1,
      }
      frame ||= requestAnimationFrame(report)
    }),
    scope.listen(element, "pointerleave", () => {
      pending = null
      options.onLeave?.()
    }),
  ]
  const cancelFrame = scope.defer(() => cancelAnimationFrame(frame))

  return () => {
    for (const stop of stopListening) stop()
    cancelFrame()
  }
}
