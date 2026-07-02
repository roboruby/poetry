import { setState } from "@poetry/controllers/helpers/state"

// Presence (P3): the mount/unmount animation convention - a helper, not a
// controller (per the primitive catalogue). Exit flips data-state to
// "closed" and HOLDS the node in the DOM until its CSS exit animation /
// transition finishes, then hands removal back to the caller via onRemove
// (this module never removes DOM); enter just flips data-state to "open"
// so the data-[state=open] animation runs. State writes go through
// setState so poetry:state-change fires like every other state flip.

// Grace (ms) added to the computed animation/transition time before the
// safety timeout fires - animationend can lag the declared duration.
const EXIT_TIMEOUT_GRACE = 100

// Safety net (ms) when a duration cannot be computed (an animation is
// declared but reports zero length): never strand a closed node in the DOM.
const EXIT_TIMEOUT_FALLBACK = 1000

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

// measure: true measures BEFORE data-state flips to "open", so the entry
// keyframe can consume the var from its first frame.
export function enterPresence(element, { measure = false, property } = {}) {
  if (measure) measurePresence(element, { property })

  setState(element, "open")
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

  setState(element, "closed")

  if (!hasExitAnimation(element)) {
    onRemove?.()
    return () => {}
  }

  let settled = false
  let timeout = null

  const cleanup = () => {
    element.removeEventListener("animationend", settle)
    element.removeEventListener("transitionend", settle)
    if (timeout !== null) window.clearTimeout(timeout)
  }

  const settle = (event) => {
    if (event && event.target !== element) return // a child's animation is not ours
    if (settled) return

    settled = true
    cleanup()
    onRemove?.()
  }

  element.addEventListener("animationend", settle)
  element.addEventListener("transitionend", settle)
  timeout = window.setTimeout(settle, exitTimeoutFor(element))

  return () => {
    settled = true
    cleanup()
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
