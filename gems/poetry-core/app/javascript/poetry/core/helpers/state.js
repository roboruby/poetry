// The controllable-state convention (the DOM is the store): runtime
// state is a set of presence-boolean data attributes - written here,
// styled by CSS variants (data-open:..., via the vendored bridge
// variants that also match the older data-state="open|closed" value
// form), owned by whichever layer set it (a Stimulus Value default, the
// DOM, the URL, or a server re-render).
//
// Keys are PAIRS (or triples): setting one member writes its attribute
// and removes its counterparts. The negative popup/panel/pressed/selected
// keys only remove, deliberately: there is no data-popup-closed -
// absence IS the state.
/** Vocabulary key -> its writes: { add: attribute | null, remove: [attributes] }. */
export const VOCABULARY = {
  open: { add: "data-open", remove: ["data-closed"] },
  closed: { add: "data-closed", remove: ["data-open"] },
  "popup-open": { add: "data-popup-open", remove: [] },
  "popup-closed": { add: null, remove: ["data-popup-open"] },
  "panel-open": { add: "data-panel-open", remove: [] },
  "panel-closed": { add: null, remove: ["data-panel-open"] },
  checked: { add: "data-checked", remove: ["data-unchecked", "data-indeterminate"] },
  unchecked: { add: "data-unchecked", remove: ["data-checked", "data-indeterminate"] },
  indeterminate: { add: "data-indeterminate", remove: ["data-checked", "data-unchecked"] },
  pressed: { add: "data-pressed", remove: [] },
  active: { add: "data-active", remove: [] },
  inactive: { add: null, remove: ["data-active"] },
  unpressed: { add: null, remove: ["data-pressed"] },
  selected: { add: "data-selected", remove: [] },
  unselected: { add: null, remove: ["data-selected"] }
}

// Derivation order: the open/closed pair first (the common ask), then the
// checked family, then the bare booleans. Attribute-only "closed" states
// (popup/panel/pressed/selected negatives) derive as undefined - callers
// that care test the attribute directly (hasAttribute("data-popup-open")).
const DERIVATION = [
  ["data-open", "open"], ["data-closed", "closed"],
  ["data-checked", "checked"], ["data-unchecked", "unchecked"],
  ["data-indeterminate", "indeterminate"],
  ["data-popup-open", "popup-open"], ["data-panel-open", "panel-open"],
  ["data-pressed", "pressed"], ["data-selected", "selected"], ["data-active", "active"]
]

/**
 * The vocabulary key `element` currently wears, per the derivation order
 * above. Attribute-only negative states (the popup/panel/pressed/selected
 * negatives) have no positive attribute to find and derive as undefined -
 * callers that care test the attribute directly.
 *
 * @param {Element} element
 * @returns {string | undefined}
 */
export function stateOf(element) {
  for (const [attribute, key] of DERIVATION) {
    if (element.hasAttribute(attribute)) return key
  }
  return undefined
}

/**
 * Writes vocabulary key `key` onto `element`: sets its add-attribute (when
 * the key has one), removes its counterparts, and announces the flip as a
 * bubbling `poetry:state-change` CustomEvent carrying `{ state: key }`.
 *
 * @param {Element} element
 * @param {string} key - a {@link VOCABULARY} key
 * @returns {string} the key that was written
 * @throws {Error} on a key outside the vocabulary
 */
export function setState(element, key) {
  const writes = VOCABULARY[key]
  if (!writes) throw new Error(`poetry state: unknown vocabulary key ${key}`)

  if (writes.add) element.setAttribute(writes.add, "")
  for (const attribute of writes.remove) element.removeAttribute(attribute)

  element.dispatchEvent(
    new CustomEvent("poetry:state-change", { detail: { state: key }, bubbles: true })
  )
  return key
}
