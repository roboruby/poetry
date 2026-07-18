import { setState } from "@poetry/controllers/helpers/state"
import { onBeforeCache } from "@poetry/controllers/helpers/turbo_cache"

// Presence (P3): the mount/unmount animation convention - a helper, not a
// controller (per the primitive catalogue). Exit flips the pair to
// data-closed and HOLDS the node in the DOM until its CSS exit animation /
// transition finishes, then hands removal back to the caller via onRemove
// (this module never removes DOM); enter just flips the pair to data-open
// so the data-open: animation runs. State writes go through setState so
// poetry:state-change fires like every other state flip.

// Grace (ms) added to the computed animation/transition time before the
// safety timeout fires - animationend can lag the declared duration.
const EXIT_TIMEOUT_GRACE = 100

// Safety net (ms) when a duration cannot be computed (an animation is
// declared but reports zero length): never strand a closed node in the DOM.
const EXIT_TIMEOUT_FALLBACK = 1000

// Exits waiting on their CSS animation. A Turbo snapshot must never
// capture one mid-flight: the owner's onRemove (hidden + layer-controller
// removal) would land AFTER the cache is taken, so the restored page
// resurrects a live layer - the click-dead restore. Every pending
// exit is flushed synchronously at turbo:before-cache; the dismissable
// layer also flushes explicitly after dispatching its before-cache
// dismiss, so exits STARTED by that dismiss complete in the same tick
// regardless of listener order.
const pendingExits = new Set()

export function flushPendingExits() {
  for (const flush of [...pendingExits]) flush()
}

if (typeof document !== "undefined") onBeforeCache(flushPendingExits)

// The measured-entry/exit hook (the Accordion contract's height mechanism):
// height keyframes cannot animate to auto, so the keyframe chain reads a
// CSS var instead. This measures the settled box - temporarily unhiding
// the element and suppressing its animations so scrollHeight reports the
// real content height - writes "<n>px" to the custom property, then
// restores exactly what it changed. The property name is overridable
// because the vendored keyframes read --accordion-panel-height.
export function measurePresence(element, { property = "--poetry-presence-height" } = {}) {
  const wasHidden = element.hidden
  const previousAnimation = element.style.animation

  if (wasHidden) element.hidden = false
  element.style.animation = "none" // a mid-flight keyframe must not skew the measure

  const height = element.scrollHeight
  element.style.setProperty(property, `${height}px`)

  element.style.animation = previousAnimation
  if (wasHidden) element.hidden = true

  return height
}

// measure: true measures BEFORE the pair flips to data-open, so the entry
// keyframe can consume the var from its first frame.
//
// Base UI transition hooks: the element enters wearing
// data-starting-style for exactly one painted frame after the pair flips
// (the Base UI two-frame trick), so CSS transitions can animate FROM the
// starting declarations. No poetry class consumes it yet - the attribute
// ships so the theme-layer milestone can adopt the transition idiom
// without touching JS.
export function enterPresence(element, { measure = false, property } = {}) {
  if (measure) measurePresence(element, { property })

  element.removeAttribute("data-ending-style") // an interrupted exit must not linger
  element.setAttribute("data-starting-style", "")
  setState(element, "open")

  if (typeof requestAnimationFrame === "function") {
    // Two frames: the first paints WITH the attribute, the removal lands
    // on the next - the transition sees both endpoints.
    requestAnimationFrame(() => {
      requestAnimationFrame(() => element.removeAttribute("data-starting-style"))
    })
  } else {
    element.removeAttribute("data-starting-style") // no rAF (bare interpreter): inert either way
  }

  return element
}

// Returns a cancel() that abandons the wait WITHOUT calling onRemove (an
// exit interrupted by a re-open). onRemove runs at most once, on the first
// of animationend / transitionend (on the element itself, not a child) or
// the safety timeout - or synchronously when no exit animation exists.
// measure: true measures while the element is STILL VISIBLE, before the
// flip to "closed" starts the exit keyframe.
export function exitPresence(element, { onRemove, measure = false, property } = {}) {
  if (measure) measurePresence(element, { property })

  // The Base UI exit hook: data-ending-style rides the whole exit
  // and leaves with the node's removal (or an interrupting re-open).
  element.setAttribute("data-ending-style", "")
  setState(element, "closed")

  if (!hasExitAnimation(element)) {
    element.removeAttribute("data-ending-style")
    onRemove?.()
    return () => {}
  }

  let settled = false
  let timeout = null

  const cleanup = () => {
    element.removeEventListener("animationend", settle)
    element.removeEventListener("transitionend", settle)
    if (timeout !== null) window.clearTimeout(timeout)
    pendingExits.delete(flush)
  }

  const settle = (event) => {
    if (event && event.target !== element) return // a child's animation is not ours
    if (settled) return

    settled = true
    cleanup()
    element.removeAttribute("data-ending-style")
    onRemove?.()
  }

  const flush = () => settle()

  element.addEventListener("animationend", settle)
  element.addEventListener("transitionend", settle)
  timeout = window.setTimeout(settle, exitTimeoutFor(element))
  pendingExits.add(flush)

  // getAnimations().finished is the Base UI end-detection: it resolves for
  // transitions AND keyframes symmetrically and needs no duration math.
  // Kept ALONGSIDE the listener+timeout paths - jsdom and the dommy tier
  // don't implement getAnimations, and settle() is idempotent.
  if (typeof element.getAnimations === "function") {
    const animations = element.getAnimations()
    if (animations.length > 0) {
      Promise.allSettled(animations.map((animation) => animation.finished))
        .then(() => settle())
    }
  }

  return () => {
    settled = true
    cleanup()
    element.removeAttribute("data-ending-style")
  }
}

// jsdom (and a bare node) report animationName as "" - treat it as "none".
function hasExitAnimation(element) {
  const style = getComputedStyle(element)
  const animated = (style.animationName || "none") !== "none"
  const transitioned = maxTimeMs(style.transitionDuration) > 0
  return animated || transitioned
}

function exitTimeoutFor(element) {
  const style = getComputedStyle(element)
  const total = Math.max(
    maxTimeMs(style.animationDuration) + maxTimeMs(style.animationDelay),
    maxTimeMs(style.transitionDuration) + maxTimeMs(style.transitionDelay)
  )
  return total > 0 ? total + EXIT_TIMEOUT_GRACE : EXIT_TIMEOUT_FALLBACK
}

// Longest entry of a comma-separated CSS time list: "0.2s, 50ms" -> 200.
function maxTimeMs(value = "") {
  return Math.max(0, ...String(value).split(",").map((time) => {
    const parsed = parseFloat(time)
    if (Number.isNaN(parsed)) return 0
    return time.trim().endsWith("ms") ? parsed : parsed * 1000
  }))
}
