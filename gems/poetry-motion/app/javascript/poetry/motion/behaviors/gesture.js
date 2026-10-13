// useGesture: press, hover and swipe on one element, through the engine's
// press and hover (which handle keyboard presses and filter emulated
// mouse events) and a swipe threshold over pointer events. Gestures are
// input, not motion, so they work under reduced motion; the effect decides
// what to animate.
import { scopeOf } from "@poetry/controllers/helpers/scope"
import { loadEngine } from "@poetry/motion/load_engine"

/**
 * Wires the handlers given until teardown(controller). onPress and
 * onHover may return an end handler, called on release and on leave.
 *
 * @param {Object} controller - the Stimulus controller instance
 * @param {HTMLElement} element - the element
 * @param {{ onPress?: Function, onHover?: Function,
 *   onSwipe?: (direction: "left"|"right"|"up"|"down") => void, threshold?: number }} handlers
 * @returns {() => void} stops early; teardown stops it otherwise
 */
export function useGesture(controller, element, handlers = {}) {
  const scope = scopeOf(controller)
  const cancels = []
  let stopped = false
  const undo = scope.defer(() => {
    stopped = true
    for (const cancel of cancels) cancel()
  })

  if (handlers.onPress || handlers.onHover) {
    loadEngine().then(({ press, hover }) => {
      if (stopped) return
      if (handlers.onPress) cancels.push(press(element, (target, event) => handlers.onPress(target, event)))
      if (handlers.onHover) cancels.push(hover(element, (target, event) => handlers.onHover(target, event)))
    })
  }

  if (handlers.onSwipe) {
    const threshold = handlers.threshold ?? 40
    let origin = null
    cancels.push(scope.listen(element, "pointerdown", (event) => {
      origin = { x: event.clientX, y: event.clientY }
    }))
    cancels.push(scope.listen(element, "pointerup", (event) => {
      if (!origin) return
      const dx = event.clientX - origin.x
      const dy = event.clientY - origin.y
      origin = null
      if (Math.max(Math.abs(dx), Math.abs(dy)) < threshold) return
      if (Math.abs(dx) >= Math.abs(dy)) handlers.onSwipe(dx > 0 ? "right" : "left")
      else handlers.onSwipe(dy > 0 ? "down" : "up")
    }))
  }

  return undo
}
