// usePresence: enter and exit animations for one connect, over the
// presence helper, with the pending exits tracked PER NODE. An exit's
// cancel used to live in one `#cancelExit` slot per controller, which a
// second exiting node (NavigationMenu's lesson) silently overwrote; here
// every node keeps its own, an enter interrupts that node's exit alone,
// and teardown abandons whatever is still exiting without running its
// removal (an interrupted exit, never a removal from a torn-down scope).
import { enterPresence, exitPresence } from "@poetry/controllers/helpers/presence"
import { scopeOf } from "@poetry/controllers/helpers/scope"

/**
 * Presence over the controller's current scope.
 *
 * @param {Object} controller - the Stimulus controller instance
 * @returns {{ enter: (element: HTMLElement, options?: Object) => HTMLElement,
 *   exit: (element: HTMLElement, options?: Object) => () => void,
 *   cancel: (element: HTMLElement) => boolean,
 *   exiting: (element: HTMLElement) => boolean }}
 */
export function usePresence(controller) {
  const pending = new Map()

  const cancel = (element) => {
    const abandon = pending.get(element)

    if (!abandon) return false

    pending.delete(element)
    abandon()

    return true
  }

  scopeOf(controller).defer(() => {
    for (const abandon of [...pending.values()]) abandon()
    pending.clear()
  })

  return {
    /**
     * Runs the entry on `element`, interrupting an exit of the same node.
     * @param {HTMLElement} element
     * @param {Object} [options] - the presence helper's enter options
     * @returns {HTMLElement} the element
     */
    enter(element, options) {
      cancel(element)

      return enterPresence(element, options)
    },
    /**
     * Runs the exit on `element`; `options.onRemove` runs once the exit
     * finishes, unless an enter or a teardown interrupts it first.
     * @param {HTMLElement} element
     * @param {Object} [options] - the presence helper's exit options
     * @param {() => void} [options.onRemove] - the caller's removal step
     * @returns {() => void} abandons this exit without removal
     */
    exit(element, { onRemove, ...options } = {}) {
      cancel(element)

      let settled = false
      const abandon = exitPresence(element, {
        ...options,
        onRemove: () => {
          settled = true
          pending.delete(element)
          onRemove?.()
        }
      })

      // A node without an exit animation settled inside the call.
      if (!settled) pending.set(element, abandon)

      return () => cancel(element)
    },
    cancel,
    /**
     * Whether `element` is mid-exit.
     * @param {HTMLElement} element
     * @returns {boolean}
     */
    exiting: (element) => pending.has(element)
  }
}
