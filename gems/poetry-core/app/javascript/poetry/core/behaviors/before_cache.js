// useBeforeCache: Turbo's before-cache moment for one connect, over the
// turbo_cache helper; the unsubscribe is registered for you.
import { scopeOf } from "@poetry/controllers/helpers/scope"
import { onBeforeCache } from "@poetry/controllers/helpers/turbo_cache"

/**
 * Subscribes `callback` to turbo:before-cache until teardown(controller).
 *
 * @param {Object} controller - the Stimulus controller instance
 * @param {(event: Event) => void} callback - must finish synchronously
 * @returns {() => void} unsubscribes early; teardown unsubscribes otherwise
 */
export function useBeforeCache(controller, callback) {
  return scopeOf(controller).defer(onBeforeCache(callback))
}
