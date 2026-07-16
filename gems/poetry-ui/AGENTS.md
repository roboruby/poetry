# AGENTS.md — poetry-ui

The component gem: the 77-component shadcn-parity catalog on ViewComponent +
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
- `bundle exec rake poetry:check[<glob>]` — the consumer-markup linter
  (`POETRY_CHECK_DESIGN=1` adds the thirteen design-slop rules)
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
- `lib/poetry/ui/testing/` — the shipped interaction testers:
  `require "poetry/ui/testing"`, include `Poetry::Ui::Testing` in a Capybara
  system test, then drive components through their REAL keyboard/pointer
  contracts (`poetry_select("#plan").select_option("Pro", via: :keyboard)`;
  also `poetry_combobox`, `poetry_dropdown_menu`, `poetry_dialog`). Write consumer
  tests THROUGH the testers, never with hand-rolled click sequences — they
  assert on the data-open/aria contract, and `bundle exec rake test:testers`
  proves them against the live preview pages (browser-gated, like visual/axe)

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
