# poetry-charts

poetry's chart tier: the shadcn chart surface as **server-rendered SVG**.

Ruby computes the geometry — data → domains → scales → ticks → points → paths
(d3-scale/d3-shape semantics, recharts' decimal-exact nice ticks) — and the
finished chart ships in the initial HTML: valid with JavaScript disabled, in
print, PDF, and email; themed by CSS variables (`--chart-1..5` + per-chart
`--color-<key>`); dark mode flips with zero re-render. A small Stimulus layer
adds tooltip/legend/active interactivity by reading **server-embedded
coordinates** — no chart math in the browser.

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

Part of the [poetry](../poetry) gem family. Status: N10 in progress.
