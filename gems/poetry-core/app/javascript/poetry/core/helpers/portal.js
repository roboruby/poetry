import { onBeforeCache } from "@poetry/controllers/helpers/turbo_cache"

// The portal-on-open mechanism: move popper
// content to a stable container (body by default) while open so it can
// position `absolute` - static under compositor scroll, immune to
// transformed ancestors - and return it HOME on close, exactly where a
// placeholder comment marks the origin.
//
// THE EVENT BRIDGE (the logical-tree trap): a component-tree portal
// re-bubbles events from its logical position; a DOM portal does not. A
// host's data-action on the component ROOT would go deaf to events
// rising out of portaled content. The bridge restores logical-tree
// bubbling for poetry's OWN

// CustomEvents (the registered list below - NEVER native events, which
// the dismissal/hotkey layers listen for at document and must see on the
// real path): propagation is CUT at the content boundary and a clone is
// re-dispatched from the home position, so above the content the event
// exists on exactly ONE path - the home one. Cancellation transfers back
// (the re-dispatch is synchronous, inside the original dispatch), and the
// real origin element rides the clone as `portalTarget` (the clone's own
// `target` is the home-side parent - a re-dispatched event cannot keep
// the original).
//
// Restore is guarded: if a Turbo morph replaced the origin while the
// popup was out, the content is DROPPED, never stranded at body. A lazy
// turbo:before-cache net force-restores everything still portaled so a
// snapshot never caches body-level popups (the zombie-popup class).
const portaled = new Map()
const bridgeEvents = new Set(["poetry:state-change"])
let cacheNetInstalled = false

/**
 * Adds event names to the bridge list. index.js registers the union of
 * every controller's declared `static events` at boot - the bridge list
 * stays honest against the manifest surface without portal.js importing
 * the controllers (no cycle).
 *
 * @param {Iterable<string>} names - full event names as emitted
 */
export function registerBridgeEvents(names) {
  for (const name of names) bridgeEvents.add(name)
}

/**
 * The portal-container seam, attribute-shaped: a host scoping themes to
 * a subtree points its overlays at a container inside that scope via
 * data-poetry-portal-container="<element id>".
 *
 * @param {Element | null} root - the element carrying the attribute
 * @returns {Element} the named container, or document.body
 */
export function resolvePortalContainer(root) {
  const id = root?.getAttribute?.("data-poetry-portal-container")

  return (id ? document.getElementById(id) : null) ?? document.body
}

/**
 * Whether `content` is currently portaled out (has a live placeholder).
 *
 * @param {Element} content
 * @returns {boolean}
 */
export function isPortaled(content) {
  return portaled.has(content)
}

/**
 * Containment that follows portals HOME: a node inside portaled content
 * counts as inside `container` when the content's home position does.
 * Focus-scope's trap keys on this - a portaled sub level is outside the
 * root content's subtree but logically inside its tree, and the trap
 * must follow the logical tree or every portaled level reads as outside.
 *
 * @param {Element} container
 * @param {Node | null} node
 * @returns {boolean}
 */
export function logicallyContains(container, node) {
  let current = node

  while (current) {
    if (container.contains(current)) return true

    const content = portaledAncestorOf(current)

    if (!content) return false

    current = portaled.get(content).placeholder.parentNode
  }

  return false
}

function portaledAncestorOf(node) {
  for (let el = node instanceof Element ? node : node?.parentElement; el; el = el.parentElement) {
    if (portaled.has(el)) return el
  }

  return null
}

/**
 * Moves `content` to `container`, leaving a placeholder comment at home
 * and wiring the event bridge for the registered list. No-op (false) when
 * already portaled or parentless. The home-effective `dir` is stamped
 * onto undeclared content for the trip, so direction-dependent behavior
 * survives the move (un-stamped on restore).
 *
 * @param {Element} content
 * @param {Object} [options]
 * @param {Element} [options.container=document.body]
 * @returns {boolean} true when the move happened
 */
export function portalContent(content, { container = document.body } = {}) {
  if (portaled.has(content) || !content.parentNode) return false

  const placeholder = document.createComment("poetry-portal")

  content.parentNode.insertBefore(placeholder, content)

  // Direction survives the move: dir inherits through the DOM, so a body
  // portal would silently flip a locally-RTL subtree back to the document
  // direction - menu arrow semantics (directionOf walks closest [dir])
  // and every CSS logical property inside the popup key on it. Stamp the
  // home-effective dir when the content declares none; restore un-stamps.
  let stampedDir = false

  if (!content.hasAttribute("dir")) {
    const dir = content.closest("[dir]")?.getAttribute("dir")

    if (dir) {
      content.setAttribute("dir", dir)
      stampedDir = true
    }
  }

  container.append(content)

  const bridges = []

  for (const type of bridgeEvents) {
    const listener = (event) => bridge(event, placeholder)

    content.addEventListener(type, listener)
    bridges.push([type, listener])
  }

  portaled.set(content, { placeholder, bridges, stampedDir })
  installCacheNet()
  return true
}

/**
 * Returns portaled `content` to its placeholder and unwires the bridge.
 * When the origin is gone (a morph replaced it) the content is DROPPED,
 * never stranded at the container.
 *
 * @param {Element} content
 * @returns {boolean} true when the content went home; false when it was
 *   not portaled, or had to be dropped
 */
export function restoreContent(content) {
  const state = portaled.get(content)

  if (!state) return false

  portaled.delete(content)
  for (const [type, listener] of state.bridges) content.removeEventListener(type, listener)
  if (state.stampedDir) content.removeAttribute("dir")

  // Home-aliveness reads the parent ELEMENT, never the comment: dommy's
  // QuickJS DOM has no Comment#isConnected (undefined reads as "origin
  // gone" and silently DROPS live content - the dommy tier caught it).
  // replaceChild over ChildNode.replaceWith for the same reason.
  const home = state.placeholder.parentNode

  if (home?.isConnected) {
    home.replaceChild(content, state.placeholder)
    return true
  }

  // The origin is gone (a morph replaced it) - drop, never strand.
  state.placeholder.parentNode?.removeChild(state.placeholder)
  content.remove()
  return false
}

// Bubble-phase on the content node itself, so the consumer's own content
// listeners (wired at connect, before any portal) always run first.
function bridge(event, placeholder) {
  const home = placeholder.parentNode

  if (!home?.isConnected) return

  event.stopPropagation()

  const clone = new CustomEvent(event.type, {
    detail: event.detail, bubbles: true,
    cancelable: event.cancelable, composed: event.composed
  })

  clone.portalTarget = event.target
  home.dispatchEvent(clone)

  if (clone.defaultPrevented) event.preventDefault()
}

function installCacheNet() {
  if (cacheNetInstalled) return

  cacheNetInstalled = true
  onBeforeCache(() => {
    for (const content of [...portaled.keys()]) restoreContent(content)
  })
}
