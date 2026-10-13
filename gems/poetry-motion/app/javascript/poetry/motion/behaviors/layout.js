// useLayout: a DOM change animated as a layout transition through the
// engine's animateView (the View Transitions API): reorder a list, move a
// tab indicator, share an element between two places. The change always
// happens; it animates only when the motion policy allows a view
// transition, so never during a Turbo visit transition, under reduced
// motion, or without the API.
import { scopeOf } from "@poetry/controllers/helpers/scope"
import { loadEngine } from "@poetry/motion/load_engine"
import { canAnimateView } from "@poetry/motion/policy"

/**
 * A runner for layout changes during this connect.
 *
 * @param {Object} controller - the Stimulus controller instance
 * @param {{ duration?: number }} [options] - milliseconds for the transition
 * @returns {(update: () => void) => Promise<void>} applies `update`, animated when allowed
 */
export function useLayout(controller, options = {}) {
  const scope = scopeOf(controller)
  let stopped = false
  scope.defer(() => {
    stopped = true
  })

  return async (update) => {
    if (stopped || !canAnimateView()) {
      update()
      return
    }
    const { animateView } = await loadEngine()
    if (stopped || !canAnimateView()) {
      update()
      return
    }
    const transition = { duration: (options.duration ?? 300) / 1000 }
    await animateView(update, transition)
  }
}
