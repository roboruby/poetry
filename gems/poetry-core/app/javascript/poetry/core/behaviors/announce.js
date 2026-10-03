// useAnnounce: the shared live regions held for one connect, over the
// announce helper; the refcount is released at teardown.
import { acquire, announce, release } from "@poetry/controllers/helpers/announce"
import { scopeOf } from "@poetry/controllers/helpers/scope"

/**
 * Takes a refcount on the shared live regions until teardown(controller)
 * and hands back the announcement surface.
 *
 * @param {Object} controller - the Stimulus controller instance
 * @returns {(message: string, politeness?: "polite" | "assertive") => void} announce
 */
export function useAnnounce(controller) {
  acquire()
  scopeOf(controller).defer(release)

  return announce
}
