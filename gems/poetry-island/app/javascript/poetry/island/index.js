// @poetry/island - the island controller, one source shipped over two
// channels: importmap-first (the engine pins this tree) and this same
// tree as the npm package for bundler hosts.
import IslandController from "@poetry/island/island_controller"

export { IslandController }

/** The island controller's identifier, as poetry_island renders it. */
export const IDENTIFIER = "poetry--island--island"

/**
 * The host one-liner: registers the island controller on the host's
 * Stimulus application.
 * @param {import("@hotwired/stimulus").Application} application
 */
export function registerPoetryIslandControllers(application) {
  application.register(IDENTIFIER, IslandController)
}
