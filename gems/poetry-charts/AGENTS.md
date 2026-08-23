# AGENTS.md — poetry-charts

The chart gem: an own server-SVG engine porting the Recharts surface —
Ruby runs the full geometry pipeline and ships finished SVG; the client only
interpolates between server-computed states or, in opt-in `live:` mode,
runs the vendored d3 kernel. Adapters (Chart.js reference)
are the swappability door.

## Gates

- `bundle exec rake test` — Ruby suite (includes the dommy tier)
- `npm test` — verifies the vendored d3 kernel build, then vitest
  (+ the drift gates: controllers_manifest, events_declaration)
- `npm run manifest` — regenerate `config/controllers_manifest.json`
- `bundle exec rake test:visual` / `test:accessibility` / `test:interaction`
  — goldens, axe, and the Chrome interaction proof
- `bundle exec rake live:fixtures` — regenerate the two-render byte-parity
  fixtures whenever engine geometry changes (client must match Ruby exactly)
- `bundle exec rake registry:verify` / `css:verify_compiled` /
  `css:verify_theme[<name>]`
- `bundle exec rubocop`

## Conventions

- Geometry is SERVER truth: controllers read embedded coordinates, never
  compute chart math (live mode is the single sanctioned exception, and it
  runs the same d3 the oracle fixtures came from).
- Polar families render in the square 250 viewBox (upstream px-ratio parity);
  the chart color ramp comes from poetry-core tokens.
- `static events` declarations follow the poetry-core rule
  (events_declaration.test.js enforces); Ruby-side wiring is declared via
  `use_stimulus`, gated by the StimulusContract like poetry-ui.
- Scope edges are declared, not implied: streaming trio only for live,
  references/errors vertical-only, brush + streaming undefined together.

## Standing rules

The naming hold: never push, publish, or claim gems.

Third-party code: adapt or bundle only from MIT-compatible sources
(MIT/ISC/BSD; Apache-2.0 carries its notice). Copyleft (GPL/LGPL/AGPL),
restricted-use, and commercial sources are patterns-and-ideas only —
never code. Every adaptation or bundled upstream: attribution in the
artifact banner or file header + license text under vendor/ + a
THIRD_PARTY_NOTICES.md entry. An adaptation change that doesn't touch
THIRD_PARTY_NOTICES.md is incomplete.
