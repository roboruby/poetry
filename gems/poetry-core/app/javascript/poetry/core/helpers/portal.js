import { onBeforeCache } from "@poetry/controllers/helpers/turbo_cache"

// The portal-on-open mechanism (docs/portal-on-open.md): move popper
// content to a stable container (body by default) while open so it can
// position `absolute` - static under compositor scroll, immune to
// transformed ancestors - and return it HOME on close, exactly where a
// placeholder comment marks the origin.
//
// THE EVENT BRIDGE (D5 - the React-vs-DOM trap): React portals bubble
// through the component tree; DOM portals do not. A host's data-action on
// the component ROOT would go deaf to events rising out of portaled
// content. The bridge restores React-portal semantics for poetry's OWN
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
// snapshot never caches body-level popups (the zombie class).
const portaled = new Map()
const bridgeEvents = new Set(["poetry:state-change"])
let cacheNetInstalled = false

// index.js registers the union of every controller's declared `static
// events` at boot - the bridge list stays honest against the manifest
// surface without portal.js importing the controllers (no cycle).
export function registerBridgeEvents(names) {
  for (const name of names) bridgeEvents.add(name)
}

// D2: the Base UI / Radix `container` prop, attribute-shaped - a host
// scoping themes to a subtree points its overlays at a container inside
// that scope. Default: body.
export function resolvePortalContainer(root) {
  const id = root?.getAttribute?.("data-poetry-portal-container")

  return (id ? document.getElementById(id) : null) ?? document.body
}

export function isPortaled(content) {
  return portaled.has(content)
}

export function portalContent(content, { container = document.body } = {}) {
  if (portaled.has(content) || !content.parentNode) return false

  const placeholder = document.createComment("poetry-portal")

  content.parentNode.insertBefore(placeholder, content)
  container.append(content)

  const bridges = []

  for (const type of bridgeEvents) {
    const listener = (event) => bridge(event, placeholder)

    content.addEventListener(type, listener)
    bridges.push([type, listener])
  }

  portaled.set(content, { placeholder, bridges })
  installCacheNet()
  return true
}

export function restoreContent(content) {
  const state = portaled.get(content)

  if (!state) return false

  portaled.delete(content)
  for (const [type, listener] of state.bridges) content.removeEventListener(type, listener)

  if (state.placeholder.isConnected) {
    state.placeholder.replaceWith(content)
    return true
  }

  // The origin is gone (a morph replaced it) - drop, never strand.
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
