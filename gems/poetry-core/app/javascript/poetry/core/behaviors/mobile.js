// useMobile: the mobile-breakpoint watch for one connect, over the
// breakpoint helper; the unwatch is registered for you.
import { watchMobile } from "@poetry/controllers/helpers/breakpoint"
import { scopeOf } from "@poetry/controllers/helpers/scope"

/**
 * Watches the mobile breakpoint until teardown(controller): `onChange`
 * runs now with the current state and again on every crossing.
 *
 * @param {Object} controller - the Stimulus controller instance
 * @param {(isMobile: boolean) => void} onChange - the handler
 * @returns {() => void} unwatches early; teardown unwatches otherwise
 */
export function useMobile(controller, onChange) {
  return scopeOf(controller).defer(watchMobile(onChange))
}
