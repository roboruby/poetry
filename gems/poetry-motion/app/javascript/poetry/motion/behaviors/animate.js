// useAnimate: one engine animation for one connect, with the motion
// policy applied. The keyframes end at the element's own,
// server-rendered style: an entrance animates FROM an offset TO where the
// server put the element. Under reduced motion nothing animates and the
// element simply keeps its style. Teardown and the Turbo cache return the
// element to that style.
import { scopeOf } from "@poetry/controllers/helpers/scope"
import { loadEngine } from "@poetry/motion/load_engine"
import { duration, easing, spring, prefersReducedMotion, entranceAllowed, track, release } from "@poetry/motion/policy"

/**
 * The engine transition for poetry's options: token names for duration,
 * easing and spring, milliseconds for a delay.
 *
 * @param {{ duration?: string|number, easing?: string, spring?: string, delay?: number }} options
 * @returns {Object}
 */
export function transitionFor(options = {}) {
  const transition = {}
  if (options.spring) Object.assign(transition, spring(options.spring))
  else transition.duration = duration(options.duration ?? "normal")
  if (options.easing && !options.spring) transition.ease = easing(options.easing)
  if (options.delay) transition.delay = options.delay / 1000
  return transition
}

/**
 * Animates `element` through `keyframes` until it finishes or
 * teardown(controller). With `entrance: true` it does not play on a cache
 * preview or a restore visit.
 *
 * @param {Object} controller - the Stimulus controller instance
 * @param {HTMLElement} element - the element to animate
 * @param {Object<string, Array>} keyframes - property => values, ending at the element's own style
 * @param {{ duration?: string|number, easing?: string, spring?: string, delay?: number, entrance?: boolean }} [options]
 * @returns {{ finished: Promise<void>, stop: () => void }}
 */
export function useAnimate(controller, element, keyframes, options = {}) {
  const scope = scopeOf(controller)
  let animation = null
  let stopped = false
  const stop = () => {
    stopped = true
    if (animation) release(animation)
  }
  const undo = scope.defer(stop)

  if (prefersReducedMotion() || (options.entrance && !entranceAllowed())) {
    undo()
    return { finished: Promise.resolve(), stop: () => {} }
  }

  const finished = loadEngine().then(({ animate }) => {
    if (stopped) return
    animation = track(animate(element, keyframes, transitionFor(options)),
      { element, properties: Object.keys(keyframes) })
    return animation.finished
  }).then(() => {})

  return { finished, stop: undo }
}
