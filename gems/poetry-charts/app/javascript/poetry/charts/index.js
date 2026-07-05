// @poetry/charts - poetry-charts' Stimulus chrome controllers + the
// BYO-engine adapter seam, one source shipped over two channels:
// importmap-first (the engine pins this tree; zero build) and this same
// tree as the npm package for bundler hosts.

import ChartTooltipController from "@poetry/charts/tooltip_controller"
import ChartAdapterController from "@poetry/charts/adapter_controller"
import ChartMotionController from "@poetry/charts/motion_controller"
import { registerChartAdapter, chartAdapter, registeredAdapters } from "@poetry/charts/adapter_registry"
import { createChartJsAdapter } from "@poetry/charts/adapters/chartjs"

export {
  ChartTooltipController,
  ChartAdapterController,
  ChartMotionController,
  registerChartAdapter,
  chartAdapter,
  registeredAdapters,
  createChartJsAdapter,
}

export function registerPoetryChartsControllers(application) {
  application.register("poetry--charts--tooltip", ChartTooltipController)
  application.register("poetry--charts--adapter", ChartAdapterController)
  application.register("poetry--charts--motion", ChartMotionController)
}
