// useLayers: the runtime layer activation (focus-scope, dismissable,
// roving-focus stacked onto content while it is open) for one connect.
// One implementation of the data-controller token add and remove that
// six overlay controllers each carried; what is still active at teardown
// is deactivated, so a torn-down overlay leaves no layer controller alive
// on an orphaned node.
import { scopeOf } from "@poetry/controllers/helpers/scope"

/**
 * Layer activation over the controller's current scope.
 *
 * @param {Object} controller - the Stimulus controller instance
 * @returns {{ activate: (element: Element, identifiers: string[]) => void,
 *   deactivate: (element: Element, identifiers: string[]) => void }}
 */
export function useLayers(controller) {
  const active = new Map()

  const deactivate = (element, identifiers) => {
    const tokens = (element.getAttribute("data-controller") ?? "")
      .split(/\s+/)
      .filter((token) => token && !identifiers.includes(token))

    element.setAttribute("data-controller", tokens.join(" "))

    const remaining = (active.get(element) ?? []).filter((token) => !identifiers.includes(token))

    if (remaining.length > 0) active.set(element, remaining)
    else active.delete(element)
  }

  scopeOf(controller).defer(() => {
    for (const [element, identifiers] of [...active]) deactivate(element, identifiers)
  })

  return {
    /**
     * Adds the identifiers to the element's data-controller, once each.
     * @param {Element} element
     * @param {string[]} identifiers
     * @returns {void}
     */
    activate(element, identifiers) {
      const tokens = (element.getAttribute("data-controller") ?? "").split(/\s+/).filter(Boolean)

      for (const identifier of identifiers) {
        if (!tokens.includes(identifier)) tokens.push(identifier)
      }

      element.setAttribute("data-controller", tokens.join(" "))
      active.set(element, [...new Set([...(active.get(element) ?? []), ...identifiers])])
    },
    deactivate
  }
}
