// The morph guard: under turbo-refresh-method=morph a Turbo refresh keeps
// the nodes the new page also has and syncs their attributes and form
// values to what the server rendered, which would strip the state a
// controller wrote onto the element (the DOM is the store, state.js): the
// selected tab, the open dialog, the expanded collapsible, the half-typed
// value. Ownership is per element AND attribute, by observation: a
// guarded attribute the client changed since the page was rendered is
// client-owned until the next full render, and the morph leaves exactly
// that attribute alone (its turbo:before-morph-attribute is cancelled).
// Everything the client never touched follows the server, so a change the
// server made on purpose still lands. A form control follows the
// browser's own rule: kept while its value differs from what the server
// rendered (value against defaultValue, checked against defaultChecked,
// selected against defaultSelected). The morph's own writes never count:
// a morph is synchronous within its task, so from its first
// turbo:before-morph-element to a zero timer (which runs after the
// microtasks that deliver the records) the observer ignores what it is
// handed. Installed once per document by registerPoetryControllers; a
// page without Turbo never fires the events, and the observer costs one
// filtered callback per client write. A node the morph replaces (no
// stable id to pair it) loses its state with the node - the guard works
// on what the morph keeps.
import { VOCABULARY } from "@poetry/controllers/helpers/state"

/**
 * The attributes a morph may not reset once the client wrote them: every
 * attribute the state vocabulary writes, and the mirrors controllers write
 * beside it (the ARIA twin of a selection, a disclosure, a check or a
 * press, the roving tabindex, hidden and its data twin, a dialog's open).
 *
 * @type {readonly string[]}
 */
export const MORPH_GUARDED_ATTRIBUTES = Object.freeze([
  ...new Set(Object.values(VOCABULARY).map((entry) => entry.add).filter(Boolean)),
  "aria-selected", "aria-expanded", "aria-checked", "aria-pressed",
  "tabindex", "hidden", "data-hidden", "open"
])

// element -> the attribute names the client owns; an entry dies with its
// element, which is how a full render releases everything.
const morphOwnership = new WeakMap()
// document -> its observer, so a second install is a no-op.
const morphGuards = new WeakMap()

/**
 * Whether the client owns `name` on `element`: it changed the attribute's
 * value since the page was rendered, outside a morph.
 *
 * @param {Element} element
 * @param {string} name - the attribute name
 * @returns {boolean}
 */
export function ownsAttribute(element, name) {
  const owned = morphOwnership.get(element)
  return !!owned && owned.has(name)
}

/**
 * Whether a form control differs from what the server rendered: the
 * browser's own dirty rule (value against defaultValue, checked against
 * defaultChecked, an option's selected against defaultSelected). A file
 * input has no server value to compare.
 *
 * @param {Element} element
 * @param {string} [name="value"] - the attribute the morph is syncing: `value`, `checked` or `selected`
 * @returns {boolean}
 */
export function isDirtyControl(element, name = "value") {
  if (element instanceof HTMLInputElement) {
    if (element.type === "file") return false
    if (name === "checked" || element.type === "checkbox" || element.type === "radio") {
      return element.checked !== element.defaultChecked
    }
    return element.value !== element.defaultValue
  }
  if (element instanceof HTMLTextAreaElement) return element.value !== element.defaultValue
  if (element instanceof HTMLOptionElement) return element.selected !== element.defaultSelected
  return false
}

/**
 * Whether a morph must leave `name` on `element` as it is: a dirty form
 * control's value, checked or selected, or a guarded attribute the client
 * owns.
 *
 * @param {Element} element - the element being morphed
 * @param {string} name - the attribute the morph would sync
 * @returns {boolean}
 */
export function keepsAttribute(element, name) {
  if (!element || !name) return false
  if (name === "value" || name === "checked" || name === "selected") return isDirtyControl(element, name)
  return ownsAttribute(element, name)
}

// True from a morph's first turbo:before-morph-element to the zero timer
// that follows it: the writes delivered meanwhile are the morph's own.
let morphInFlight = false

/**
 * Records the client's writes as the observer delivers them. A write that
 * left the value as it was (a controller re-asserting state on connect)
 * is no change and owns nothing; an addition and a removal both are.
 * Nothing is recorded while a morph is in flight.
 *
 * @param {MutationRecord[]} records
 */
function recordMorphOwnership(records) {
  if (morphInFlight) return
  for (const { target, attributeName: name, oldValue } of records) {
    if (!name || oldValue === target.getAttribute(name)) continue
    let owned = morphOwnership.get(target)
    if (!owned) morphOwnership.set(target, (owned = new Set()))
    owned.add(name)
  }
}

/**
 * Installs the guard on `doc` once: the attribute observer that records
 * the client's writes, the window that ignores a morph's own writes, and
 * the `turbo:before-morph-attribute` listener that keeps what the client
 * owns. Returns false when it is already installed, or when the
 * environment has no MutationObserver.
 *
 * @param {Document} [doc=document]
 * @returns {boolean} true when this call installed it
 */
export function installMorphGuard(doc = document) {
  if (!doc || !doc.documentElement || typeof MutationObserver === "undefined") return false
  if (morphGuards.has(doc)) return false

  const observer = new MutationObserver(recordMorphOwnership)
  observer.observe(doc.documentElement, {
    attributes: true, attributeOldValue: true, subtree: true, attributeFilter: [...MORPH_GUARDED_ATTRIBUTES]
  })

  doc.addEventListener("turbo:before-morph-element", () => {
    if (morphInFlight) return
    morphInFlight = true
    setTimeout(() => {
      morphInFlight = false
    }, 0)
  })
  doc.addEventListener("turbo:before-morph-attribute", (event) => {
    if (keepsAttribute(event.target, event.detail && event.detail.attributeName)) event.preventDefault()
  })

  morphGuards.set(doc, observer)
  return true
}
