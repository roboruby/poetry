// usePortal: content moved to a portal container for one connect, over
// the portal helper. Every node this instance portals is restored at
// teardown (drop-never-strand: a node whose origin is gone is dropped by
// the helper), so no controller writes its own restore-on-disconnect.
import { portalContent, restoreContent } from "@poetry/controllers/helpers/portal"
import { scopeOf } from "@poetry/controllers/helpers/scope"

/**
 * Portal moves over the controller's current scope.
 *
 * @param {Object} controller - the Stimulus controller instance
 * @returns {{ portal: (content: Element, options?: Object) => boolean,
 *   restore: (content: Element) => boolean }}
 */
export function usePortal(controller) {
  const moved = new Set()

  scopeOf(controller).defer(() => {
    for (const content of [...moved]) restoreContent(content)
    moved.clear()
  })

  return {
    /**
     * Moves `content` to the container; a no-op when already portaled.
     * @param {Element} content
     * @param {Object} [options] - the portal helper's options (container)
     * @returns {boolean} true when the move happened
     */
    portal(content, options) {
      const happened = portalContent(content, options)

      if (happened) moved.add(content)

      return happened
    },
    /**
     * Returns `content` home now.
     * @param {Element} content
     * @returns {boolean} true when the content went home
     */
    restore(content) {
      moved.delete(content)

      return restoreContent(content)
    }
  }
}
