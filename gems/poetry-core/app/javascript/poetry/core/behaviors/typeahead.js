// useTypeahead: one typeahead per connect, over the typeahead helper,
// with its buffer timer reset at teardown - the leak the hand-rolled
// field initializers (menu, select, tree) never closed.
import { scopeOf } from "@poetry/controllers/helpers/scope"
import { createTypeahead } from "@poetry/controllers/helpers/typeahead"

/**
 * A typeahead instance whose pending timer is cleared at
 * teardown(controller).
 *
 * @param {Object} controller - the Stimulus controller instance
 * @returns {{ pending: () => boolean, reset: () => void,
 *   search: (key: string, items: Element[], options?: Object) => Element | null }}
 */
export function useTypeahead(controller) {
  const typeahead = createTypeahead()

  scopeOf(controller).defer(() => typeahead.reset())

  return typeahead
}
