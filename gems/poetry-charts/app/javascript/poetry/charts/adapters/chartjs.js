// The Chart.js reference adapter: the proof of the seam,
// and the documented escape valve for the one case the SVG default is
// weak on (huge point counts - canvas draws one bitmap). poetry ships NO
// Chart.js: the host imports it and passes the constructor in -
//
//   import Chart from "chart.js/auto"
//   import { registerChartAdapter, createChartJsAdapter } from "@poetry/charts"
//   registerChartAdapter("chartjs", createChartJsAdapter(Chart))
//
// Declared degradations (the canvas tax, stated instead of discovered):
// tooltips/legends fall back to Chart.js's built-ins (poetry's HTML chrome
// cannot overlay per-point without the engine's hit data), CSS variables
// resolve to frozen pixels at paint (dark-mode flips repaint the whole
// chart), and per-part data-slot styling does not exist on a bitmap.
export function createChartJsAdapter(Chart) {
  const TYPES = { area: "line", line: "line", bar: "bar", pie: "pie", radar: "radar" }

  function config(spec, helpers) {
    const type = TYPES[spec.type]
    const categoryKey = spec.axes?.x?.dataKey ?? spec.axes?.y?.dataKey
    const labels = spec.data.map((row) => (categoryKey ? row[categoryKey] : ""))

    const datasets = spec.series.map((series) => {
      const key = series.dataKey
      const color = helpers.resolveColor(colorFor(spec, key))
      return {
        label: spec.config?.[key]?.label ?? key,
        data: spec.data.map((row) => row[key] ?? null),
        backgroundColor: color,
        borderColor: color,
        fill: spec.type === "area",
        stack: series.stack ?? undefined,
      }
    })

    return {
      type,
      data: { labels, datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: spec.type === "bar" && spec.axes?.y?.dataKey ? "y" : "x",
        plugins: { legend: { display: spec.series.length > 1 } },
      },
    }
  }

  function colorFor(spec, key) {
    return spec.config?.[key]?.color ?? `var(--color-${key})`
  }

  return {
    supports: Object.keys(TYPES),
    degradations: [
      "tooltip and legend chrome fall back to Chart.js built-ins",
      "CSS variables resolve to frozen pixels at paint; theme flips repaint",
      "no per-part data-slot styling on canvas",
      "radial charts unsupported (no Chart.js equivalent)",
    ],

    render(el, spec, helpers) {
      const canvas = document.createElement("canvas")
      el.replaceChildren(canvas)
      return new Chart(canvas, config(spec, helpers))
    },

    destroy(instance) {
      instance?.destroy()
    },

    themeChanged(instance, spec, helpers) {
      const el = instance.canvas.parentElement
      instance.destroy()
      const canvas = document.createElement("canvas")
      el.replaceChildren(canvas)
      return new Chart(canvas, config(spec, helpers))
    },
  }
}
