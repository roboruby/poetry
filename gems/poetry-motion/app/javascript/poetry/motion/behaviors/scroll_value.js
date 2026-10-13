// useScrollValue: a progress value from 0 to 1 tied to scrolling, for the
// page or for an element passing through the viewport. Under reduced
// motion it reports 1, the finished state, once and never follows the
// scroll.
import { scopeOf } from "@poetry/controllers/helpers/scope"
import { loadEngine } from "@poetry/motion/load_engine"
import { prefersReducedMotion } from "@poetry/motion/policy"

/**
 * Calls `onProgress` with the scroll progress until teardown(controller).
 *
 * @param {Object} controller - the Stimulus controller instance
 * @param {(progress: number) => void} onProgress - the handler, 0 to 1
 * @param {{ target?: Element, container?: Element, offset?: string[], axis?: "x"|"y" }} [options]
 * @returns {() => void} stops early; teardown stops it otherwise
 */
export function useScrollValue(controller, onProgress, options = {}) {
  const scope = scopeOf(controller)
  let cancel = () => {}
  let stopped = false
  const undo = scope.defer(() => {
    stopped = true
    cancel()
  })

  if (prefersReducedMotion()) {
    onProgress(1)
    return undo
  }

  loadEngine().then(({ scroll }) => {
    if (stopped) return
    cancel = scroll((progress) => onProgress(progress), options)
  })

  return undo
}
