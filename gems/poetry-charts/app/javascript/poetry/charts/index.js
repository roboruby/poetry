// @poetry/charts - poetry-charts' Stimulus chrome controllers + the
// BYO-engine adapter seam, one source shipped over two channels:
// importmap-first (the engine pins this tree; zero build) and this same
// tree as the npm package for bundler hosts.

import ChartTooltipController from "@poetry/charts/tooltip_controller"
import ChartAdapterController from "@poetry/charts/adapter_controller"
import ChartMotionController from "@poetry/charts/motion_controller"
import ChartLiveController from "@poetry/charts/live_controller"
import ChartWindowController from "@poetry/charts/window_controller"
import { registerChartAdapter, chartAdapter, registeredAdapters } from "@poetry/charts/adapter_registry"
import { createChartJsAdapter } from "@poetry/charts/adapters/chartjs"

export {
  ChartTooltipController,
  ChartAdapterController,
  ChartMotionController,
  ChartLiveController,
  ChartWindowController,
  registerChartAdapter,
  chartAdapter,
  registeredAdapters,
  createChartJsAdapter,
}

export function registerPoetryChartsControllers(application) {
  application.register("poetry--charts--tooltip", ChartTooltipController)
  application.register("poetry--charts--adapter", ChartAdapterController)
  application.register("poetry--charts--motion", ChartMotionController)
  application.register("poetry--charts--live", ChartLiveController)
  application.register("poetry--charts--window", ChartWindowController)
  installMorphGuard()
}

// Turbo page morphs (idiomorph) can rebuild an inline <svg> root in the
// XHTML namespace - an HTMLUnknownElement whose children are real SVG
// nodes but paint NOTHING (computed styles normal, every bbox 0x0). The
// corrupted subtree is REPLACED, not morphed, so no per-element event
// offers an interception point - instead, after every page morph, any
// chart svg in the wrong namespace is reparsed through the HTML parser
// (innerHTML handles svg foreign content correctly). This listener is
// registered at application boot, so it runs BEFORE the motion
// controller's own turbo:morph restart re-queries the svg.
const SVG_NS = "http://www.w3.org/2000/svg"
let morphGuardInstalled = false
function installMorphGuard() {
  if (morphGuardInstalled || typeof document === "undefined") return
  morphGuardInstalled = true

  document.addEventListener("turbo:morph", () => {
    for (const svg of document.querySelectorAll('[data-slot="chart-svg"]')) {
      if (svg.namespaceURI === SVG_NS) continue
      const holder = document.createElement("div")
      holder.innerHTML = svg.outerHTML
      const repaired = holder.querySelector("svg")
      if (repaired) svg.replaceWith(repaired)
    }
  })
}
