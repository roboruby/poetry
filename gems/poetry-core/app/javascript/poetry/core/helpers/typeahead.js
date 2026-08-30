// The APG typeahead buffer (P2), shared: printable keys accumulate into a
// search buffer that resets after a timeout (1s default), matching wraps
// from the current item, and a repeated same-letter buffer cycles matches.
// Extracted VERBATIM from menu_controller.js (the Select contract's gated
// extraction) so the menu family and the Select listbox run the identical
// algorithm - the buffer/timer state lives in the instance this factory
// returns, one per consuming controller.

/**
 * The label an item types against: data-text-value overrides textContent
 * (icon-rich content, the Radix textValue prop).
 *
 * @param {Element} item
 * @returns {string} the trimmed label ("" when neither source exists)
 */
export function typeaheadLabel(item) {
  return (item.dataset.textValue ?? item.textContent ?? "").trim()
}

/**
 * One typeahead instance for a consuming controller - the buffer/timer
 * state lives in the returned object (the module header holds the
 * algorithm).
 *
 * @returns {{ pending: () => boolean, reset: () => void,
 *   search: (key: string, items: Element[], options?: Object) => Element | null }}
 */
export function createTypeahead() {
  let buffer = ""
  let timer = null

  return {
    /**
     * A live buffer means Space extends the search instead of activating.
     * @returns {boolean}
     */
    pending() {
      return buffer !== ""
    },

    /** Clears the buffer and cancels its reset timer. */
    reset() {
      window.clearTimeout(timer)
      timer = null
      buffer = ""
    },

    /**
     * Radix's getNextMatch: a repeated same-letter buffer cycles matches;
     * a growing buffer keeps the current item first so continued typing
     * stays put while it still matches; single-letter search excludes the
     * current item so it always advances. The consumer decides what a
     * match means (menus focus it; a closed Select trigger commits it).
     *
     * @param {string} key - the printable key just typed
     * @param {Element[]} items - ENABLED items only (disabled filtering
     *   is the consumer's collection contract)
     * @param {Object} [options]
     * @param {Element | null} [options.active=null] - the item the walk
     *   starts from
     * @param {number} [options.timeout=1000] - ms before the buffer resets
     * @param {(item: Element) => string} [options.labelOf=typeaheadLabel]
     * @returns {Element | null} the matched item
     */
    search(key, items, { active = null, timeout = 1000, labelOf = typeaheadLabel } = {}) {
      window.clearTimeout(timer)
      timer = window.setTimeout(() => { buffer = "" }, timeout)
      buffer += key

      if (items.length === 0) return null

      const repeated = buffer.length > 1 && Array.from(buffer).every((char) => char === buffer[0])
      const search = (repeated ? buffer[0] : buffer).toLowerCase()
      const currentIndex = Math.max(items.indexOf(active), 0)

      let ordered = items.map((_, offset) => (currentIndex + offset) % items.length)

      if (search.length === 1) ordered = ordered.filter((index) => items[index] !== active)

      const match = ordered.find((index) => labelOf(items[index]).toLowerCase().startsWith(search))

      return match === undefined ? null : items[match]
    }
  }
}
