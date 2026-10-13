import { configureEngine } from "@poetry/motion/policy"

// The one door to the vendored kernels. Each is pinned without preload and
// imported nowhere statically, so a page fetches it the first time an
// effect asks, and never on a page without one: the engine for the
// behaviors, confetti and the globe for their own effects.
let pending = null
const kernels = {}

/**
 * The engine module, fetched once per page lifetime and configured by the
 * motion policy.
 *
 * @returns {Promise<Object>}
 */
export function loadEngine() {
  pending ??= import("@poetry/motion/engine").then(configureEngine)
  return pending
}

/**
 * The canvas-confetti kernel (create), fetched once.
 *
 * @returns {Promise<Object>}
 */
export function loadConfetti() {
  kernels.confetti ??= import("@poetry/motion/confetti")
  return kernels.confetti
}

/**
 * The cobe kernel (createGlobe), fetched once.
 *
 * @returns {Promise<Object>}
 */
export function loadGlobe() {
  kernels.globe ??= import("@poetry/motion/globe")
  return kernels.globe
}
