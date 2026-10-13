// @poetry/motion - poetry-motion's behaviors and motion policy, one source
// shipped over two channels: importmap-first (the engine pins this tree)
// and this same tree as the npm package for bundler hosts.

import { installPolicy } from "@poetry/motion/policy"

export {
  prefersReducedMotion, onReducedMotionChange, track, flush, release, entranceAllowed, canAnimateView, visitInFlight,
  token, duration, easing, spring, installPolicy,
} from "@poetry/motion/policy"
export { loadEngine } from "@poetry/motion/load_engine"

/**
 * The host one-liner: registers the motion controllers on the host's
 * Stimulus application and installs the motion policy.
 *
 * @param {import("@hotwired/stimulus").Application} _application
 * @returns {void}
 */
export function registerPoetryMotionControllers(_application) {
  installPolicy()
}
