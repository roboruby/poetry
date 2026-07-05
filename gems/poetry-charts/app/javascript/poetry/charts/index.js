// @poetry/charts - poetry-charts' Stimulus chrome controllers, one source
// shipped over two channels: importmap-first (the engine pins this
// tree; zero build) and this same tree as the npm package for bundler hosts.

import ChartTooltipController from "@poetry/charts/tooltip_controller"

export { ChartTooltipController }

export function registerPoetryChartsControllers(application) {
  application.register("poetry--charts--tooltip", ChartTooltipController)
}
