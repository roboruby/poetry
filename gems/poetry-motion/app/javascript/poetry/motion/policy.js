// The motion policy: decided once, read by every motion behavior.
//
// - Reduced motion: the user's prefers-reduced-motion, or data-motion on
//   <html> ("reduce" forces it, "full" overrides it) for an in-app setting.
//   Under reduce, behaviors jump to their end state, and the engine's own
//   MotionGlobalConfig.skipAnimations is set once it loads.
// - Tokens: --motion-duration-*, --motion-ease-* and --motion-spring-*
//   from the theme, read at the moment of use.
// - The Turbo cache: the engine writes inline styles frame by frame, so a
//   snapshot taken mid-animation freezes an in-between frame, and the
//   engine's complete() only lands on the next frame, after Turbo has
//   cloned the page. The server renders every effect's finished state, so
//   the end of every animation is the element's own style: at
//   turbo:before-cache each tracked animation stops and the inline
//   properties it wrote are removed, now and once more after the engine's
//   next render, which would write the stopped value back.
// - One view-transition slot: a document runs one view transition at a
//   time, and a Turbo visit transition skips a layout animation started
//   beside it. canAnimateView() is false while a visit is in flight.
//
// The listeners are page-lifetime and installed once (installPolicy).

const REDUCE_QUERY = "(prefers-reduced-motion: reduce)"
const running = new Map()
const reducedListeners = new Set()
let installed = false
let visiting = false
let restoring = false
let engine = null

/**
 * Whether motion is reduced for this page right now.
 *
 * @returns {boolean}
 */
export function prefersReducedMotion() {
  const setting = document.documentElement.dataset.motion
  if (setting === "reduce") return true
  if (setting === "full") return false
  return typeof window.matchMedia === "function" && window.matchMedia(REDUCE_QUERY).matches
}

/**
 * Calls fn with the new reduced state whenever it changes (the media query
 * or the data-motion attribute). Returns the unsubscribe.
 *
 * @param {Function} fn
 * @returns {Function}
 */
export function onReducedMotionChange(fn) {
  installPolicy()
  reducedListeners.add(fn)
  return () => reducedListeners.delete(fn)
}

/**
 * Keeps a running animation in the policy's care until it finishes. At
 * turbo:before-cache it stops, and the inline properties it writes on the
 * element are removed, so the snapshot shows the server-rendered finished
 * state. Without an element the animation completes instead (a Web
 * Animation, which leaves no inline style). Returns the animation.
 *
 * @param {Object} animation playback controls with stop(), complete() and finished
 * @param {Object} [target]
 * @param {HTMLElement} [target.element] the element the animation writes
 * @param {string[]} [target.properties] the CSS properties it writes inline
 * @param {Function} [target.finish] restores anything else it wrote (text a ticker counts), run after it stops
 * @returns {Object}
 */
export function track(animation, { element = null, properties = [], finish = null } = {}) {
  installPolicy()
  running.set(animation, { element, properties, finish })
  const forget = () => running.delete(animation)
  Promise.resolve(animation.finished).then(forget, forget)
  return animation
}

/**
 * Ends every tracked animation at its finished state, synchronously.
 * Turbo calls it through turbo:before-cache, and it runs when reduced
 * motion turns on mid-animation.
 *
 * @returns {void}
 */
export function flush() {
  for (const animation of [...running.keys()]) release(animation)
}

/**
 * Ends one tracked animation at its finished state, synchronously, and
 * forgets it: an inline-animated element gets its own style back, now and
 * after the engine's next render; a Web Animation completes. Behaviors
 * release their animations at teardown.
 *
 * @param {Object} animation a tracked animation
 * @returns {void}
 */
export function release(animation) {
  const target = running.get(animation)
  if (!target) return

  running.delete(animation)
  const { element, properties, finish } = target
  if (finish) {
    settle(() => animation.stop())
    finish()
    return
  }
  if (!element) {
    settle(() => animation.complete())
    return
  }
  settle(() => animation.stop())
  const clear = () => { for (const property of properties) element.style.removeProperty(property) }
  clear()
  engine?.frame?.postRender(clear)
}

/**
 * Whether an entrance may play now. Not on Turbo's cache preview, and not
 * while a back or forward visit restores a page the user already saw.
 *
 * @returns {boolean}
 */
export function entranceAllowed() {
  return !restoring && !document.documentElement.hasAttribute("data-turbo-preview")
}

// Runs a playback call, ignoring an animation that already ended.
function settle(call) {
  try {
    call()
  } catch (_error) {
    // An animation already stopped has nothing left to end.
  }
}

/**
 * Whether a layout animation may start now: the browser has View
 * Transitions, motion is not reduced, and no Turbo visit holds the slot.
 *
 * @returns {boolean}
 */
export function canAnimateView() {
  return !visiting && typeof document.startViewTransition === "function" && !prefersReducedMotion()
}

/**
 * Whether a Turbo visit is between its start and its render.
 *
 * @returns {boolean}
 */
export function visitInFlight() {
  return visiting
}

/**
 * The raw value of a motion token, or "" when the theme does not set it.
 *
 * @param {string} name the token without its prefix ("duration-fast")
 * @returns {string}
 */
export function token(name) {
  return getComputedStyle(document.documentElement).getPropertyValue(`--motion-${name}`).trim()
}

/**
 * A duration in seconds (the engine's unit) from a token name or from
 * milliseconds. Reduced motion is 0.
 *
 * @param {string|number} value "fast", "normal", "slow" or milliseconds
 * @returns {number}
 */
export function duration(value) {
  if (prefersReducedMotion()) return 0
  const raw = typeof value === "number" || /^\d+$/.test(value) ? `${value}ms` : token(`duration-${value}`)
  const match = /^([\d.]+)(ms|s)$/.exec(raw)
  if (!match) throw new Error(`poetry-motion: unknown duration ${JSON.stringify(value)}`)
  const amount = Number(match[1])
  return match[2] === "ms" ? amount / 1000 : amount
}

/**
 * An easing token as the engine's cubic-bezier array.
 *
 * @param {string} name "standard", "emphasized" or "exit"
 * @returns {number[]}
 */
export function easing(name) {
  const match = /^cubic-bezier\(([^)]+)\)$/.exec(token(`ease-${name}`))
  if (!match) throw new Error(`poetry-motion: unknown easing ${JSON.stringify(name)}`)
  return match[1].split(",").map(Number)
}

/**
 * A spring token as the engine's spring options.
 *
 * @param {string} name "gentle", "snappy" or "bouncy"
 * @returns {{type: string, stiffness: number, damping: number, mass: number}}
 */
export function spring(name) {
  const parts = token(`spring-${name}`).split(/\s+/).map(Number)
  if (parts.length !== 3 || parts.some(Number.isNaN)) {
    throw new Error(`poetry-motion: unknown spring ${JSON.stringify(name)}`)
  }
  const [stiffness, damping, mass] = parts
  return { type: "spring", stiffness, damping, mass }
}

/**
 * Hands the loaded engine to the policy: its global skip flag follows
 * reduced motion from now on. Returns the engine.
 *
 * @param {Object} loaded the engine module
 * @returns {Object}
 */
export function configureEngine(loaded) {
  installPolicy()
  engine = loaded
  syncEngine()
  return loaded
}

/**
 * Installs the page-lifetime listeners once: Turbo's cache and visit
 * events, the reduced-motion query and the data-motion attribute.
 *
 * @returns {void}
 */
export function installPolicy() {
  if (installed) return
  installed = true

  document.addEventListener("turbo:before-cache", flush)
  document.addEventListener("turbo:visit", (event) => {
    visiting = true
    restoring = event.detail?.action === "restore"
  })
  for (const done of ["turbo:render", "turbo:fetch-request-error", "turbo:visit-error"]) {
    document.addEventListener(done, () => { visiting = false })
  }
  // Controllers connect while the page renders, before turbo:load: the
  // restore flag holds through that render.
  document.addEventListener("turbo:load", () => {
    visiting = false
    restoring = false
  })

  const notify = () => {
    syncEngine()
    const reduced = prefersReducedMotion()
    if (reduced) flush()
    for (const fn of reducedListeners) fn(reduced)
  }
  if (typeof window.matchMedia === "function") {
    window.matchMedia(REDUCE_QUERY).addEventListener?.("change", notify)
  }
  new MutationObserver(notify).observe(document.documentElement, { attributes: true, attributeFilter: ["data-motion"] })
}

// Sets the engine's skip flag from the reduced state.
function syncEngine() {
  if (engine?.MotionGlobalConfig) engine.MotionGlobalConfig.skipAnimations = prefersReducedMotion()
}
