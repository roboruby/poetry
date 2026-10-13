import { configureEngine } from "@poetry/motion/policy"

// The one door to the vendored engine. It is pinned without preload and
// imported nowhere statically, so a page fetches it the first time a
// behavior asks, and never on a page without motion elements.
let pending = null

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
