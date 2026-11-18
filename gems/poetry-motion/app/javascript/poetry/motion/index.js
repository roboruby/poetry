// @poetry/motion - poetry-motion's effects, behaviors and motion policy,
// one source shipped over two channels: importmap-first (the engine pins
// this tree) and this same tree as the npm package for bundler hosts.
//
// The controllers register eagerly, as poetry-core's do: the entry imports
// all of them (about 6 KB gzipped together) and registers them at once, so
// a press on an effect in the first moments after paint reaches a live
// controller. A lazily imported controller lost those presses: a click
// that dispatched while its module was still in flight found nothing to
// handle it. The animation engine and the kernels stay on demand through
// loadEngine(), loadConfetti() and loadGlobe().

import { installPolicy } from "@poetry/motion/policy"
import AnimatedListController from "@poetry/motion/animated_list_controller"
import ConfettiController from "@poetry/motion/confetti_controller"
import DockController from "@poetry/motion/dock_controller"
import DraggableController from "@poetry/motion/draggable_controller"
import GlobeController from "@poetry/motion/globe_controller"
import LayoutGroupController from "@poetry/motion/layout_group_controller"
import MagneticController from "@poetry/motion/magnetic_controller"
import MarqueeController from "@poetry/motion/marquee_controller"
import NumberTickerController from "@poetry/motion/number_ticker_controller"
import ParallaxController from "@poetry/motion/parallax_controller"
import ParticlesController from "@poetry/motion/particles_controller"
import ScrambleController from "@poetry/motion/scramble_controller"
import ScrollProgressController from "@poetry/motion/scroll_progress_controller"
import SpotlightCardController from "@poetry/motion/spotlight_card_controller"
import SwipeCardsController from "@poetry/motion/swipe_cards_controller"
import TextRevealController from "@poetry/motion/text_reveal_controller"
import TiltCardController from "@poetry/motion/tilt_card_controller"
import TypewriterController from "@poetry/motion/typewriter_controller"
import WordRotateController from "@poetry/motion/word_rotate_controller"

export {
  prefersReducedMotion, onReducedMotionChange, track, flush, release, entranceAllowed, canAnimateView, visitInFlight,
  token, duration, easing, spring, installPolicy,
} from "@poetry/motion/policy"
export { loadEngine } from "@poetry/motion/load_engine"

/**
 * Each effect's identifier and its controller class, the map
 * registerPoetryMotionControllers registers.
 *
 * @type {Object<string, Function>}
 */
export const CONTROLLERS = {
  "poetry--motion--animated-list": AnimatedListController,
  "poetry--motion--confetti": ConfettiController,
  "poetry--motion--dock": DockController,
  "poetry--motion--draggable": DraggableController,
  "poetry--motion--globe": GlobeController,
  "poetry--motion--layout-group": LayoutGroupController,
  "poetry--motion--magnetic": MagneticController,
  "poetry--motion--marquee": MarqueeController,
  "poetry--motion--number-ticker": NumberTickerController,
  "poetry--motion--parallax": ParallaxController,
  "poetry--motion--particles": ParticlesController,
  "poetry--motion--scramble": ScrambleController,
  "poetry--motion--scroll-progress": ScrollProgressController,
  "poetry--motion--spotlight-card": SpotlightCardController,
  "poetry--motion--swipe-cards": SwipeCardsController,
  "poetry--motion--text-reveal": TextRevealController,
  "poetry--motion--tilt-card": TiltCardController,
  "poetry--motion--typewriter": TypewriterController,
  "poetry--motion--word-rotate": WordRotateController,
}

/**
 * The host one-liner: installs the motion policy and registers every
 * effect controller on the host's Stimulus application.
 *
 * @param {import("@hotwired/stimulus").Application} application
 * @returns {Promise<void>} settled: the controllers are registered when it returns
 */
export function registerPoetryMotionControllers(application) {
  installPolicy()
  for (const [identifier, controller] of Object.entries(CONTROLLERS)) application.register(identifier, controller)
  return Promise.resolve()
}
