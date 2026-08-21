# AGENTS.md — poetry-ui

The component gem: the 87-component shadcn-parity catalog on ViewComponent +
Stimulus (machinery from poetry-core), themed by the cn-* layer — nine complete
visual fragments under `themes/`.

## Gates — run what your change touches, all of it before "done"

- `bundle exec rake test` — unit suite + the dommy middle tier
- `bundle exec rake test:accessibility` — axe over every preview page
- `bundle exec rake test:visual` — screenshot goldens. The differ passes at
  byte-equal OR ≤0.1% pixels; a ~3px shadow ramp sits UNDER that tolerance, so
  when bytes legitimately change, re-record and keep goldens byte-honest.
- `bundle exec rake css:verify_compiled` and `css:verify_theme[<name>]` —
  dictionary ↔ compiled ↔ theme drift (all nine themes)
- `bundle exec rake registry:verify` — component_registry.yml drift
  (regenerate with `rake registry:generate`, never hand-edit)
- `bundle exec rake css:template_classes:verify` — the safelist-harvest
  drift gate (regenerate with `css:template_classes:generate` after any
  template class change; hosts purge what this scan doesn't see)
- `bundle exec rake poetry:check[<glob>]` — the consumer-markup linter
  (`POETRY_CHECK_DESIGN=1` adds the 23 design-slop rules)
- `bundle exec rake design:lint` — design-slop, both tiers (AST + dommy DOM);
  `design:verify` gates the nine committed DESIGN.md exports
- `bundle exec rubocop`
- `bundle exec rake eval:verify` — the eval regression net (poetry arms fully
  green, every raw arm keeps its planted tell); `eval:scorecard` prints the
  card. The judged half (`eval:capture` + `eval:judge`) and the generated-arm
  benchmark (`eval:benchmark:*`, N15 W2) are on-demand, never CI — doctrine
  in `eval/README.md`.

## Layout

- `app/components/poetry/ui/<name>/` — component.rb + style.rb (the class
  dictionary) + preview sidecars
- `themes/*.css` — the nine theme fragments; port-time edits go through the
  plans in `script/theme_port/plans/`
- `docs/testing.md` — the three-tier testing doctrine (wiring / behavior /
  browser); `docs/*-port-ledger.txt` — per-theme residuals, kept current
- `eval/` — the harness: frozen arms + runner (mechanical), judge + captures
  + committed results (judged); `eval/README.md` is the doctrine
- `lib/generators/poetry/` — the install surface (installer, per-adapter
  generators, the AGENTS/skills sections) and `block/templates/*.html.erb`,
  the canonical source of the eight blocks (docs previews render these
  files per request)
- `lib/poetry/ui/testing/` — the shipped interaction testers:
  `require "poetry/ui/testing"`, include `Poetry::Ui::Testing` in a Capybara
  system test, then drive components through their REAL keyboard/pointer
  contracts (`poetry_select("#plan").select_option("Pro", via: :keyboard)`;
  also `poetry_combobox`, `poetry_dropdown_menu`, `poetry_dialog`). Write consumer
  tests THROUGH the testers, never with hand-rolled click sequences — they
  assert on the data-open/aria contract, and `bundle exec rake test:testers`
  proves them against the live preview pages (browser-gated, like visual/axe)

## Component conventions

- Stimulus wiring is declared in Ruby via the `use_stimulus` DSL (48
  components do); the StimulusContract gate verifies declarations against
  poetry-core's controllers manifest, and the registry / agent surface /
  docs all project from them — wire nothing by hand-writing `data-*`.
- DOM ids go through the StableId plumbing (`key:` derives dom_id-first,
  explicit `id:` wins); never mint bare random ids — keyed identity is
  what keeps Turbo morph and fragment caches honest (`poetry:check` warns
  on unkeyed components in loops and cache blocks).
- Utilities live where the harvest sees them: the template-class scan
  reads literal classes in templates, NOT strings interpolated from Ruby.
  Anything that must reach host safelists belongs in a Style dictionary
  element or a literal template attribute — an interpolated utility
  builds fine here and purges in every host.

## Known traps

- Stimulus controller traps live in the vault note "Components Library -
  Stimulus Controller Gotchas" — read it before touching a controller, add
  what you learn.
- Kill CSS transitions/animations before cross-style computed reads;
  double-rAF is NOT settled.
- Tailwind box-shadow never computes "none" while ring/shadow var plumbing is
  live — parse layers and filter transparent zeros.
- Preview sidecars are class-level; variant axes must be `style` attributes,
  not `option`s.
- `render SomeComponent.new(...) { "text" }` binds the block to `.new`, not
  `render` — the content silently vanishes and the element paints empty
  while DOM checks stay green. Use the `poetry_*` helpers (or parenthesize
  `render(Component.new(...)) { }`). The eval's `links_have_accessible_names`
  gate exists because the judge caught exactly this.

## Standing rules

- The naming hold: never push, publish, or claim gems.
- Commit per logical change; registry and safelist artifacts are generated —
  regenerate, don't edit.
- Third-party code: adapt only from MIT-compatible sources (MIT/ISC/BSD;
  Apache-2.0 carries its notice). Copyleft (GPL/LGPL/AGPL), restricted-use,
  and commercial sources are patterns-and-ideas only — never code. Every
  adaptation: source URL in the file/component comment + a
  THIRD_PARTY_NOTICES.md section (upstream, license, adapted files, full
  license text). An adaptation change that doesn't touch
  THIRD_PARTY_NOTICES.md is incomplete.
