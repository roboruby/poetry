// useSpring: a value that springs to each new target, interrupted and
// retargeted without a jump, written to one CSS property (a custom
// property or an individual transform like `scale`). Under reduced motion
// set() writes the target at once. Teardown removes the property, so the
// element returns to its own style.
import { scopeOf } from "@poetry/controllers/helpers/scope"
import { loadEngine } from "@poetry/motion/load_engine"
import { prefersReducedMotion, spring, track, release } from "@poetry/motion/policy"

/**
 * A spring on `property` of `element`.
 *
 * @param {Object} controller - the Stimulus controller instance
 * @param {HTMLElement} element - the element whose style it writes
 * @param {string} property - the CSS property (`--tilt-x`, `scale`, ...)
 * @param {{ spring?: string, unit?: string }} [options]
 * @returns {{ set: (value: number) => Promise<void>, stop: () => void }}
 */
export function useSpring(controller, element, property, options = {}) {
  const scope = scopeOf(controller)
  const unit = options.unit ?? ""
  let animation = null
  let stopped = false

  const write = (value) => element.style.setProperty(property, `${value}${unit}`)
  const halt = () => {
    if (animation) release(animation)
    animation = null
  }
  const undo = scope.defer(() => {
    stopped = true
    halt()
    element.style.removeProperty(property)
  })

  const set = async (value) => {
    if (stopped) return
    if (prefersReducedMotion()) {
      halt()
      write(value)
      return
    }
    const { animate } = await loadEngine()
    if (stopped) return
    const previous = animation
    animation = track(animate(element, { [property]: `${value}${unit}` }, spring(options.spring ?? "snappy")),
      { element, properties: [property] })
    if (previous) previous.stop()
    await animation.finished
  }

  return { set, stop: undo }
}
