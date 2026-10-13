// @poetry/motion - poetry-motion's effects, behaviors and motion policy,
// one source shipped over two channels: importmap-first (the engine pins
// this tree) and this same tree as the npm package for bundler hosts.

import { installPolicy } from "@poetry/motion/policy"
import MarqueeController from "@poetry/motion/marquee_controller"
import TextRevealController from "@poetry/motion/text_reveal_controller"
import NumberTickerController from "@poetry/motion/number_ticker_controller"
import TiltCardController from "@poetry/motion/tilt_card_controller"

export {
  prefersReducedMotion, onReducedMotionChange, track, flush, release, entranceAllowed, canAnimateView, visitInFlight,
  token, duration, easing, spring, installPolicy,
} from "@poetry/motion/policy"
export { loadEngine } from "@poetry/motion/load_engine"
export { MarqueeController, TextRevealController, NumberTickerController, TiltCardController }

/**
 * The host one-liner: registers the effect controllers on the host's
 * Stimulus application and installs the motion policy.
 *
 * @param {import("@hotwired/stimulus").Application} application
 * @returns {void}
 */
export function registerPoetryMotionControllers(application) {
  application.register("poetry--motion--marquee", MarqueeController)
  application.register("poetry--motion--text-reveal", TextRevealController)
  application.register("poetry--motion--number-ticker", NumberTickerController)
  application.register("poetry--motion--tilt-card", TiltCardController)
  installPolicy()
}
