// useStagger: one animation across a list, each element starting a step
// after the last. Same contract as useAnimate: the keyframes end at each
// element's own style, and reduced motion, teardown and the Turbo cache
// leave every element there.
import { scopeOf } from "@poetry/controllers/helpers/scope"
import { loadEngine } from "@poetry/motion/load_engine"
import { prefersReducedMotion, entranceAllowed, track, release } from "@poetry/motion/policy"
import { transitionFor } from "@poetry/motion/behaviors/animate"

/**
 * Animates `elements` in order, `step` milliseconds apart.
 *
 * @param {Object} controller - the Stimulus controller instance
 * @param {HTMLElement[]} elements - the elements, in order
 * @param {Object<string, Array>} keyframes - property => values, ending at each element's own style
 * @param {{ step?: number, duration?: string|number, easing?: string, spring?: string, entrance?: boolean }} [options]
 * @returns {{ finished: Promise<void>, stop: () => void }}
 */
export function useStagger(controller, elements, keyframes, options = {}) {
  const scope = scopeOf(controller)
  const list = [...elements]
  const animations = []
  let stopped = false
  const undo = scope.defer(() => {
    stopped = true
    for (const animation of animations) release(animation)
  })

  if (list.length === 0 || prefersReducedMotion() || (options.entrance && !entranceAllowed())) {
    undo()
    return { finished: Promise.resolve(), stop: () => {} }
  }

  const finished = loadEngine().then(({ animate, stagger }) => {
    if (stopped) return
    const base = transitionFor(options)
    const delays = stagger((options.step ?? 50) / 1000, { startDelay: base.delay ?? 0 })
    const properties = Object.keys(keyframes)
    list.forEach((element, index) => {
      const transition = { ...base, delay: delays(index, list.length) }
      animations.push(track(animate(element, keyframes, transition), { element, properties }))
    })
    return Promise.all(animations.map((animation) => animation.finished))
  }).then(() => {})

  return { finished, stop: undo }
}
