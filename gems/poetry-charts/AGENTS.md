# AGENTS.md — poetry-charts

The chart gem: an own server-SVG engine porting the source's chart surface —
Ruby runs the full geometry pipeline and ships finished SVG; the client only
interpolates between server-computed states or, in opt-in `live:` mode,
runs the vendored d3 kernel. Nine families (area, bar, line, pie, radar,
radial bar, scatter, composed, and the adapter frame) with the shared
container, legend, and tooltip parts; adapters (Chart.js reference) are
the swappability door.

## Gates

- `bundle exec rake` — the default chain: `test`, `test:dommy`, `rubocop`,
  `css:verify_theme`, `css:verify_rendered`, `herb:compile`, `yard:verify`,
  `yard:coverage`. Green before every commit.
- `npm test` — verifies the vendored d3 kernel build (`vendor:d3:verify`),
  then vitest (+ the drift gates: controllers_manifest, events_declaration).
- `npm run manifest` — regenerate `config/controllers_manifest.json`;
  `npm run vendor:d3` rebuilds the kernel from `vendor/d3-kernel/` (its
  README is the doctrine: the exact d3 packages the geometry fixtures came
  from, unmodified, attribution banner included).
- `bundle exec rake test:visual` / `test:accessibility` / `test:interaction`
  — goldens, axe, and the Chrome interaction proof.
- `bundle exec rake live:fixtures` — regenerate the two-render byte-parity
  fixtures whenever engine geometry changes (client must match Ruby exactly).
- `bundle exec rake registry:verify` / `css:verify_compiled` /
  `css:verify_theme[<name>]` — registry and dictionary ↔ theme drift.
- Templates must compile under `Herb::Engine`; every public object is
  documented (YARD floors at 0) — same rules as poetry-core.

## Conventions

- Geometry is SERVER truth: controllers read embedded coordinates, never
  compute chart math (live mode is the single sanctioned exception, and it
  runs the same d3 the oracle fixtures came from).
- Polar families render in the square 250 viewBox (source px-ratio parity);
  the chart color ramp comes from poetry-core tokens (the source's legacy
  blue base ramp — recorded as a parity delta in core's DESIGN.md).
- `themes/*.css` carry the per-theme chart rules, ported from the source's
  style stylesheets like poetry-ui's themes; poetry-ui's theme fidelity
  ledger records the pin and the deviations.
- `static events` declarations follow the poetry-core rule
  (events_declaration.test.js enforces); Ruby-side wiring is declared via
  `use_stimulus`, gated by the StimulusContract like poetry-ui.
- Two ways to render a library component, chosen by who is authoring.
  Inside a component template (and its Ruby), render siblings by class —
  `render Poetry::Charts::Container::Component.new(...)` — never through
  the `helpers` proxy: the `poetry_*` helpers are mixed into ActionView's
  base, not ViewComponent's, so they are undefined here, and the proxy
  couples the component to whatever view context is rendering. Host-side
  code — docs pages, previews, generated code — uses the `poetry_*`
  helper: the registry, editor snippets, skills, and `poetry:check` key on
  helper names and do not parse `render Klass.new`. poetry-ui's AGENTS.md
  carries the same rule with a carve-out for parts that exist only as
  helpers; this gem has none — every helper is a thin wrapper over one
  class.
- Doc comments follow the poetry-core rule: file/class narration stays
  `//`; every PUBLIC method and exported function/constant carries a
  JSDoc `/** ... */` block with `@param`/`@returns`. No comment may
  quote a dispatch call or its option tokens (the events scan reads raw
  source), and comments carry poetry's rules - never other libraries'
  names or anonymous "upstream" comparisons; attribution lives in
  THIRD_PARTY_NOTICES.md alone.
- Scope edges are declared, not implied: streaming trio only for live,
  references/errors vertical-only, brush + streaming undefined together.

## Standing rules

Releases: versions move in lockstep across the family, with internal
dependencies pinned exactly (`= VERSION`); bumps happen only on the
maintainer's explicit go. Publishing runs only through the tag-triggered
release workflow (OIDC trusted publishing) — never `gem push` by hand. The
CHANGELOG stays bare until 0.1.0; commit messages carry the record.
Sibling gems ride local paths in the Gemfile only when checked out side by
side; the lockfile is not committed.

Naming: "Poetry" is the product in prose; gem names, constants, and
identifiers stay as they are.

Third-party code: adapt or bundle only from MIT-compatible sources
(MIT/ISC/BSD; Apache-2.0 carries its notice). Copyleft (GPL/LGPL/AGPL),
restricted-use, and commercial sources are patterns-and-ideas only —
never code. Bundled upstreams keep their attribution banner and license
text under vendor/; every adaptation notes "Adapted from an MIT-licensed
source (source and license in THIRD_PARTY_NOTICES.md)" in its class doc.
Both get a THIRD_PARTY_NOTICES.md entry (the d3 modules,
decimal.js-light, and the recharts nice-tick transcription under
`vendor/d3-kernel/`; the chart anatomy and theme rules under the
shadcn/ui section) — source URLs live there, never in code. An
adaptation change that doesn't touch THIRD_PARTY_NOTICES.md is
incomplete.
