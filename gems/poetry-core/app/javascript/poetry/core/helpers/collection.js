// The DOM is the registry (Tier 1): collection items are read from the
// document in DOM order - no client-side bookkeeping (the Radix
// `collection` primitive collapses to a query).

export const COLLECTION_ITEM_SELECTOR = "[data-poetry-collection-item]"

export function collectionItems(root, selector = COLLECTION_ITEM_SELECTOR) {
  return Array.from(root.querySelectorAll(selector))
}
