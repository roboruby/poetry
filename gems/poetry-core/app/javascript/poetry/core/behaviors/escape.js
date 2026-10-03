// useEscape: capture-phase Escape handling (IME cancels filtered) for one
// connect, over the escape helper; the unsubscribe is registered for you.
import { onEscapeKeydown } from "@poetry/controllers/helpers/escape"
import { scopeOf } from "@poetry/controllers/helpers/scope"

/**
 * Subscribes `callback` to Escape keydowns until teardown(controller).
 *
 * @param {Object} controller - the Stimulus controller instance
 * @param {(event: KeyboardEvent) => void} callback - the handler
 * @param {Object} [options] - the escape helper's options (capture, target)
 * @returns {() => void} unsubscribes early; teardown unsubscribes otherwise
 */
export function useEscape(controller, callback, options) {
  return scopeOf(controller).defer(onEscapeKeydown(callback, options))
}
