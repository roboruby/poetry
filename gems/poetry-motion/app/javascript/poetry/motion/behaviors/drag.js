// useDrag: free dragging with pointer capture, an axis lock and bounds,
// written to the element's translate. On release the element springs back
// to its own style unless onEnd keeps it (returns true). Dragging is
// direct manipulation, so it works under reduced motion; only the spring
// back is skipped there.
import { scopeOf } from "@poetry/controllers/helpers/scope"
import { useSpring } from "@poetry/motion/behaviors/spring"
import { prefersReducedMotion } from "@poetry/motion/policy"

/**
 * Makes `element` draggable until teardown(controller).
 *
 * @param {Object} controller - the Stimulus controller instance
 * @param {HTMLElement} element - the element to drag
 * @param {{ axis?: "x"|"y", bounds?: { left?: number, right?: number, top?: number, bottom?: number },
 *   onMove?: (offset: { x: number, y: number }) => void,
 *   onEnd?: (offset: { x: number, y: number }) => boolean|void, spring?: string }} [options]
 * @returns {() => void} stops early; teardown stops it otherwise
 */
export function useDrag(controller, element, options = {}) {
  const scope = scopeOf(controller)
  const x = useSpring(controller, element, "--motion-drag-x", { unit: "px", spring: options.spring })
  const y = useSpring(controller, element, "--motion-drag-y", { unit: "px", spring: options.spring })
  const bounds = options.bounds ?? {}
  const clamp = (value, low, high) => Math.min(high ?? Infinity, Math.max(low ?? -Infinity, value))
  let start = null

  const place = (offset) => {
    element.style.setProperty("--motion-drag-x", `${offset.x}px`)
    element.style.setProperty("--motion-drag-y", `${offset.y}px`)
    element.style.translate = "var(--motion-drag-x, 0px) var(--motion-drag-y, 0px)"
  }
  const offsetFor = (event) => ({
    x: options.axis === "y" ? 0 : clamp(event.clientX - start.x, bounds.left, bounds.right),
    y: options.axis === "x" ? 0 : clamp(event.clientY - start.y, bounds.top, bounds.bottom),
  })

  const stops = [
    scope.listen(element, "pointerdown", (event) => {
      if (event.button !== 0) return
      start = { x: event.clientX, y: event.clientY, pointer: event.pointerId }
      element.setPointerCapture?.(event.pointerId)
      element.dataset.dragging = ""
    }),
    scope.listen(element, "pointermove", (event) => {
      if (!start || event.pointerId !== start.pointer) return
      const offset = offsetFor(event)
      place(offset)
      options.onMove?.(offset)
    }),
    scope.listen(element, "pointerup", (event) => end(event)),
    scope.listen(element, "pointercancel", (event) => end(event)),
  ]
  const end = (event) => {
    if (!start || event.pointerId !== start.pointer) return
    const offset = offsetFor(event)
    start = null
    delete element.dataset.dragging
    element.releasePointerCapture?.(event.pointerId)
    if (options.onEnd?.(offset) === true) return
    if (prefersReducedMotion()) {
      settle()
      return
    }
    Promise.all([x.set(0), y.set(0)]).then(settle)
  }
  const settle = () => {
    element.style.removeProperty("--motion-drag-x")
    element.style.removeProperty("--motion-drag-y")
    element.style.removeProperty("translate")
  }
  const undo = scope.defer(() => {
    delete element.dataset.dragging
    settle()
  })

  return () => {
    for (const stop of stops) stop()
    undo()
  }
}
