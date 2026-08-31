// The DOM is the registry: collection items are read from the document
// in DOM order - no client-side bookkeeping, no registration step; a
// membership question is always a fresh query.

/** The attribute marking an element as a collection item. */
export const COLLECTION_ITEM_SELECTOR = "[data-poetry-collection-item]"

/**
 * The collection items under `root`, in DOM order.
 *
 * @param {ParentNode} root - the element (or document) to query
 * @param {string} [selector] - override for consumers with their own item
 *   marker (defaults to {@link COLLECTION_ITEM_SELECTOR})
 * @returns {Element[]}
 */
export function collectionItems(root, selector = COLLECTION_ITEM_SELECTOR) {
  return Array.from(root.querySelectorAll(selector))
}
