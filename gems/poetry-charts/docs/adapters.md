# Bringing your own chart engine

poetry-charts' default engine renders every chart as **server-side SVG** —
no JavaScript required, themed live by CSS variables. When you need a
different engine (typically canvas for very large datasets, or a library
your team already owns), three doors exist, cheapest first.

## Door 1 — the frame accepts anything

`poetry_chart_container(config:)` is engine-agnostic: it scopes the chart
id, emits the per-series `--color-<key>` variables for both themes, and
carries the aspect-ratio chrome. Put any markup inside it — hand-rolled
SVG, a third-party widget — and you keep the theming contract.

## Door 2 — the adapter seam (the real swap)

Change one word and the same call routes to your engine:

```erb
<%= poetry_chart :bar, engine: "chartjs",
      data: @data, config: chart_config,
      series: [{ data_key: :desktop }],
      axes: { x: { data_key: :month } } %>
```

The server validates and embeds the **frozen chart-spec v1** (closed
vocabulary — unknown keys raise at render); the `poetry--charts--adapter`
controller hands it to the adapter registered under that name and owns
the lifecycle (render on connect, destroy on disconnect, repaint on theme
flips). Note the trade: the adapter path takes `series:`/`axes:`
**arguments**, not the compositional slots — the slot grammar belongs to
the default engine.

### The Chart.js reference adapter

poetry ships the adapter as a factory and **zero dependencies** — you
import Chart.js yourself:

```js
import Chart from "chart.js/auto"
import { registerChartAdapter, createChartJsAdapter } from "@poetry/charts"

registerChartAdapter("chartjs", createChartJsAdapter(Chart))
```

Declared degradations (the canvas tax, stated up front): tooltips/legends
fall back to Chart.js built-ins; CSS variables resolve to frozen pixels at
paint (theme flips repaint the whole chart); no per-part `data-slot`
styling; radial charts unsupported.

### Writing your own adapter

```js
registerChartAdapter("myengine", {
  supports: ["line", "bar"],                    // optional type allowlist
  degradations: ["..."],                        // declared, never discovered
  render(el, spec, { resolveColor }) { ... },   // -> instance
  destroy(instance, el) { ... },
  themeChanged(instance, spec, helpers) { ... } // optional dark-mode repaint
})
```

`resolveColor("var(--color-desktop)")` returns the concrete value at the
chart's scope — the helper that closes the canvas/CSS-variable gap.

A typed-core charting engine fits this seam naturally (one whose framework-free core is
framework-free): `render` instantiates an `XYContainer` with components
built from the spec's series, `destroy` tears it down. Its CSS-variable
theming (`--vis-color0..5`) bridges from `--chart-1..5` in a few lines.

## Door 3 — the React island (Recharts itself)

For a React charting library, use poetry's bounded island escape-hatch
a Stimulus-mounted island (`props-in / events-out, never a client
router`) rendered INSIDE `poetry_chart_container`, so the theme tokens
still flow. This is the sanctioned home for actual Recharts — with the
caveat that it inherits Recharts' blank-until-hydration behavior, which
the default engine exists to avoid.
