// useFrame: a callback every animation frame, paused while the element is
// off screen and while the tab is hidden. Under reduced motion the loop
// never starts, and it stops if reduced motion turns on mid-run.
import { scopeOf } from "@poetry/controllers/helpers/scope"
import { useInView } from "@poetry/controllers/behaviors/in_view"
import { loadEngine } from "@poetry/motion/load_engine"
import { prefersReducedMotion, onReducedMotionChange } from "@poetry/motion/policy"

/**
 * Runs `callback(timestamp, delta)` every frame while `element` is visible,
 * until teardown(controller).
 *
 * @param {Object} controller - the Stimulus controller instance
 * @param {Element} element - the element whose visibility gates the loop
 * @param {(timestamp: number, delta: number) => void} callback - the frame work
 * @returns {{ running: () => boolean, stop: () => void }}
 */
export function useFrame(controller, element, callback) {
  const scope = scopeOf(controller)
  let engine = null
  let visible = false
  let loop = null
  let stopped = false

  const sync = () => {
    const wanted = !stopped && visible && !document.hidden && !prefersReducedMotion() && engine
    if (wanted && !loop) {
      loop = ({ timestamp, delta }) => callback(timestamp, delta)
      engine.frame.update(loop, true)
    } else if (!wanted && loop) {
      engine.cancelFrame(loop)
      loop = null
    }
  }

  const stop = scope.defer(() => {
    stopped = true
    sync()
  })
  if (prefersReducedMotion()) return { running: () => false, stop }

  scope.listen(document, "visibilitychange", sync)
  scope.defer(onReducedMotionChange(sync))
  useInView(controller, element, (inView) => {
    visible = inView
    sync()
  })
  loadEngine().then((loaded) => {
    engine = loaded
    sync()
  })

  return { running: () => loop !== null, stop }
}
