// @poetry/controllers - poetry's Stimulus controllers + DOM helpers, one
// source shipped over two channels: importmap-first (the engine
// pins this tree; zero build) and this same tree as the npm package for
// esbuild / Vite / jsbundling hosts. Never requires a bundler.

import StateController from "@poetry/controllers/state_controller"

export { default as StateController } from "@poetry/controllers/state_controller"
export * from "@poetry/controllers/helpers/state"
export * from "@poetry/controllers/helpers/collection"
export * from "@poetry/controllers/helpers/direction"
export * from "@poetry/controllers/helpers/tabbable"
export * from "@poetry/controllers/helpers/escape"

// identifier -> controller class, for every sidecar controller poetry ships.
export const controllers = {
  "poetry--core--state": StateController
}

// The bundler-host one-liner: registers every poetry controller on the
// host's Stimulus application (importmap hosts get the same registrations
// via the engine's pins + this same call in their controllers/index.js).
export function registerPoetryControllers(application) {
  for (const [identifier, controller] of Object.entries(controllers)) {
    application.register(identifier, controller)
  }
  return application
}
