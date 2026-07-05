# poetry-charts

poetry's chart tier: the shadcn chart surface as **server-rendered SVG**.

Ruby computes the geometry — data → domains → scales → ticks → points → paths
(d3-scale/d3-shape semantics, recharts' decimal-exact nice ticks) — and the
finished chart ships in the initial HTML: valid with JavaScript disabled, in
print, PDF, and email; themed by CSS variables (`--chart-1..5` + per-chart
`--color-<key>`); dark mode flips with zero re-render. A small Stimulus layer
adds tooltip/legend/active interactivity by reading **server-embedded
coordinates** — no chart math in the browser.

Entrance animation is on by default (recharts' defaults per family: bars
400ms, everything else 1500ms ease) and stays doctrine-pure: the CSS motion
tier animates between server-computed states (line dash draw-in, area clip
reveal, bars growing from the value baseline, radar rising from the polar
center). `animate: false` opts a chart out; `prefers-reduced-motion` users
always get the finished chart in the initial paint.

Engines are swappable (three doors — full recipes in `docs/adapters.md`):

1. **The frame** (container/config/style + tooltip/legend chrome) is
   engine-agnostic — the contract all three official shadcn ports share.
2. **Adapters**: every chart also compiles to a closed, versioned chart-spec;
   a duck-typed adapter (`render(el, spec)` / `update` / `destroy`) routes it
   to another engine per chart via `engine:`. Chart.js ships as the reference
   adapter (canvas — the big-data escape valve).
3. **Islands**: React chart libraries (Recharts included) run inside the frame
   via poetry's bounded island escape-hatch.

Scope: the measured shadcn parity surface — 6 chart families, 70 blocks
(area / bar / line / pie / radar / radial + tooltip variants).

## Install

```ruby
# Gemfile
gem "poetry-charts"
```

The engine merges its importmap pins automatically (`@poetry/charts`) —
no build step. The tooltip chrome boots with one registration in your
Stimulus entrypoint:

```js
import { registerPoetryChartsControllers } from "@poetry/charts"
registerPoetryChartsControllers(application)
```

The motion tier is one `@import` in your CSS build (the engine also exposes
it to Propshaft as `poetry-charts.css`); skip it and charts render static:

```css
@import "poetry-charts/app/assets/stylesheets/poetry-charts.css";
```

Interactive charts are **real forms**: submit a filter, the chart
re-renders on the server (Turbo makes it smooth; the mechanics need no
JS). See `docs/adapters.md` for BYO engines.

Part of the [poetry](../poetry) gem family. Status: N10 complete —
six families, 52 gallery examples, the frozen spec-v1 adapter seam.
