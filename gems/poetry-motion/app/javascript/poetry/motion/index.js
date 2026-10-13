// @poetry/motion - poetry-motion's effects, behaviors and motion policy,
// one source shipped over two channels: importmap-first (the engine pins
// this tree) and this same tree as the npm package for bundler hosts.
//
// The controllers register lazily: registerPoetryMotionControllers watches
// the page for a poetry--motion--* identifier and imports that one
// controller the first time it appears, so a page without an effect loads
// none of them, and a page with one loads only its own.

import { installPolicy } from "@poetry/motion/policy"

export {
  prefersReducedMotion, onReducedMotionChange, track, flush, release, entranceAllowed, canAnimateView, visitInFlight,
  token, duration, easing, spring, installPolicy,
} from "@poetry/motion/policy"
export { loadEngine } from "@poetry/motion/load_engine"

/**
 * Each effect's identifier and the import that loads its controller, the
 * map registerPoetryMotionControllers loads from.
 *
 * @type {Object<string, Function>}
 */
export const CONTROLLERS = {
  "poetry--motion--animated-list": () => import("@poetry/motion/animated_list_controller"),
  "poetry--motion--confetti": () => import("@poetry/motion/confetti_controller"),
  "poetry--motion--dock": () => import("@poetry/motion/dock_controller"),
  "poetry--motion--draggable": () => import("@poetry/motion/draggable_controller"),
  "poetry--motion--globe": () => import("@poetry/motion/globe_controller"),
  "poetry--motion--layout-group": () => import("@poetry/motion/layout_group_controller"),
  "poetry--motion--magnetic": () => import("@poetry/motion/magnetic_controller"),
  "poetry--motion--marquee": () => import("@poetry/motion/marquee_controller"),
  "poetry--motion--number-ticker": () => import("@poetry/motion/number_ticker_controller"),
  "poetry--motion--parallax": () => import("@poetry/motion/parallax_controller"),
  "poetry--motion--particles": () => import("@poetry/motion/particles_controller"),
  "poetry--motion--scramble": () => import("@poetry/motion/scramble_controller"),
  "poetry--motion--scroll-progress": () => import("@poetry/motion/scroll_progress_controller"),
  "poetry--motion--spotlight-card": () => import("@poetry/motion/spotlight_card_controller"),
  "poetry--motion--swipe-cards": () => import("@poetry/motion/swipe_cards_controller"),
  "poetry--motion--text-reveal": () => import("@poetry/motion/text_reveal_controller"),
  "poetry--motion--tilt-card": () => import("@poetry/motion/tilt_card_controller"),
  "poetry--motion--typewriter": () => import("@poetry/motion/typewriter_controller"),
  "poetry--motion--word-rotate": () => import("@poetry/motion/word_rotate_controller"),
}

const PREFIX = "poetry--motion--"

/**
 * The host one-liner: installs the motion policy and registers each
 * effect controller on the host's Stimulus application the first time its
 * identifier appears in the page, now or after any later render.
 *
 * @param {import("@hotwired/stimulus").Application} application
 * @returns {Promise<void>} settles once the controllers already on the page are registered
 */
export function registerPoetryMotionControllers(application) {
  installPolicy()
  const requested = new Map()

  const load = (identifier) => {
    if (requested.has(identifier) || !CONTROLLERS[identifier]) return requested.get(identifier)
    const loading = CONTROLLERS[identifier]().then((module) => application.register(identifier, module.default))
    requested.set(identifier, loading)
    return loading
  }
  const scan = (root) => {
    const found = []
    const elements = root.querySelectorAll ? [root, ...root.querySelectorAll(`[data-controller*="${PREFIX}"]`)] : []
    for (const element of elements) {
      for (const identifier of (element.getAttribute?.("data-controller") ?? "").split(/\s+/)) {
        if (identifier.startsWith(PREFIX)) found.push(load(identifier))
      }
    }
    return found
  }

  new MutationObserver((records) => {
    for (const record of records) {
      if (record.type === "attributes") scan(record.target)
      else for (const node of record.addedNodes) if (node.nodeType === 1) scan(node)
    }
  }).observe(document.documentElement, {
    childList: true, subtree: true, attributes: true, attributeFilter: ["data-controller"]
  })

  return Promise.all(scan(document.documentElement)).then(() => {})
}
