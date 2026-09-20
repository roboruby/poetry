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

Engines are swappable (three doors — full recipes in the Charts adapter guide on the poetry docs site):

1. **The frame** (container/config/style + tooltip/legend chrome) is
   engine-agnostic — the contract all three official shadcn ports share.
2. **Adapters**: every chart also compiles to a closed, versioned chart-spec;
   a duck-typed adapter (`render(el, spec)` / `update` / `destroy`) routes it
   to another engine per chart via `engine:`. Chart.js ships as the reference
   adapter (canvas — the big-data escape valve).
3. **Islands**: React chart libraries (Recharts included) run inside the frame
   via poetry's bounded island escape-hatch.

Scope: shadcn's chart surface — nine families (area, bar, line, pie, radar,
radial bar, scatter and composed, plus the adapter frame) with their tooltip
and legend variants.

## Install

```ruby
# Gemfile
gem "poetry-charts"
```

Hosts running poetry-ui can wire everything below in one shot —
`bin/rails g poetry:install --charts` — and skip the rest of this
section.

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
JS). Give a chart a stable `id:` and it **morphs** between those server
renders — under any same-context swap (Turbo Drive/Frames/Streams), the
new render starts from the old geometry and tweens to its own; a shape
change (points added/removed) replays the entrance instead, recharts'
own update behavior. See the Charts adapter guide on the poetry docs site for BYO engines.

For data that can't round-trip (streaming metrics, tickers), the
cartesian trio takes `live: true`: the chart embeds its `{spec, frame}`
payload and a client renderer — running on the vendored
`@poetry/charts/d3` kernel, proven byte-equal to the Ruby engine —
redraws it in place. Feed it either channel:

```js
// 1. Replace the payload script's JSON (what a turbo_stream.update does)
script.textContent = JSON.stringify({ ...payload, spec: { ...payload.spec, data } })
// 2. Or dispatch on the chart frame
frame.dispatchEvent(new CustomEvent("poetry-chart:update", { detail: { data } }))
```

Updates tween through the same FLIP machinery, the tooltip keeps serving
fresh values mid-stream, and `prefers-reduced-motion` snaps. Live data
carries pre-formatted category strings (lambdas can't ride JSON — the
server raises a teaching error on `tick_formatter`/`labels`).

Part of the [poetry](../poetry) gem family. Status:
nine families, 46 gallery examples, the frozen spec-v1 adapter seam.

## License

Available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
See `THIRD_PARTY_NOTICES.md` for adapted code.
