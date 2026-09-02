# AGENTS.md — poetry-ui

The component gem: the 87-component shadcn-parity catalog on ViewComponent +
Stimulus (machinery from poetry-core), themed by the cn-* layer — nine complete
visual fragments under `themes/`.

## Gates — run what your change touches, all of it before "done"

- `bundle exec rake` — the default chain: `test`, `test:dommy`, `rubocop`,
  `registry:verify`, `css:template_classes:verify`, `herb:compile`,
  `css:verify_compiled`, `css:verify_selected_bridge`,
  `css:verify_reduced_motion`, `css:verify_theme`, `css:verify_fidelity`,
  `css:verify_rendered`, `css:verify_hooks`, `css:verify_vars`,
  `design:verify`, `eval:verify`, `goldens:verify_inputs`, `yard:verify`,
  `yard:coverage`. Green before every commit. The unit suite also carries
  the part, stimulus, styled-state, and dictionary-fidelity contracts.
- `bundle exec rake test:accessibility` — axe over every preview page.
- `bundle exec rake test:visual` — screenshot goldens for the default
  theme; `POETRY_THEME=<t>` walks a ported theme; `test:visual:all` walks
  all nine (Chrome, ~5 minutes per theme, one at a time). The differ passes
  at byte-equal OR ≤0.1% pixels, so a sub-tolerance geometry shift
  (a 2px nudge on three boxes) passes silently — after any deliberate
  geometry change, re-bless on purpose. Review diffs with
  `bundle exec ruby script/visual_review.rb <theme>` (baseline | candidate |
  diff sheets in `tmp/visual_review`), then re-bless the named shots:
  `POETRY_THEME=<t> POETRY_VISUAL_ONLY=<a>,<b> VISUAL_REBASELINE=1 bundle
  exec rake test:visual`. The walk also fails any shot where a visible svg
  is more than 2px larger than its box (an unsized icon falls back to
  24px). The dialog family is shot opened as well as closed.
- `bundle exec rake poetry:check[<glob>]` — the consumer-markup linter
  (`POETRY_CHECK_DESIGN=1` adds the 23 design-slop rules); `design:lint`
  runs design-slop over the gem's own templates and previews.
- `bundle exec rake eval:verify` — the eval regression net (poetry arms fully
  green, every raw arm keeps its planted tell); `eval:scorecard` prints the
  card. The judged half (`eval:capture` + `eval:judge`) and the generated-arm
  benchmark (`eval:benchmark:*`) are on-demand, never CI — doctrine
  in `eval/README.md`.
- CI (`.github/workflows/main.yml`) adds `bundle-audit` and the Herb
  linter (`rake herb:lint`, rules pinned in `.herb.yml`).

## The two fidelity ledgers

Every theme and every dictionary is held against the pinned source (a
tagged shadcn release; the pin lives in `lib/poetry/ui/themes.rb` and the
snapshot filenames):

- `config/theme_fidelity/` — each `themes/<t>.css` rule against the
  source's `style-<t>.css`; `css:verify_fidelity` holds
  `deviations.yml` and the actual diff in exact two-way agreement.
- `config/dictionary_fidelity/` — each Style dictionary's structural tokens
  against the source's classNames per `data-slot`, read from rendered
  previews; the gate is `test/poetry/ui/dictionary_fidelity_test.rb`
  (`rake css:verify_dictionary_fidelity` runs it with a report in
  `tmp/dictionary_fidelity/diffs.json`).

Change a theme rule or a dictionary token → reconcile the matching
`deviations.yml` in the same change, with a reason. An unrecorded
difference fails; a recorded one that no longer exists fails as stale.
Moving the pin is a ceremony (`css:upstream_delta OLD= NEW=`, then
`css:fidelity_snapshot` + `css:dictionary_snapshot` at the new commit,
`script/hook_coverage/refresh_snapshot.rb <clone> <pin>`, reconcile, walk
all nine themes).

## Layout

- `app/components/poetry/ui/<name>/` — component.rb + style.rb (the class
  dictionary) + preview sidecars.
- `themes/*.css` — the nine theme fragments; the default theme is the
  classic source translated onto the cn-* layer, the eight ports are the
  source's style stylesheets.
- `docs/design/*.design.md` — the nine DESIGN.md exports (`design:export_all`;
  committed, gated by `design:verify`, not shipped in the gem).
- the three-tier testing doctrine (wiring / behavior / browser) governs
  `test/` — the consumer-facing guide lives on the docs site.
- `eval/` — the harness: frozen arms + runner (mechanical), judge + captures
  + committed results (judged); `eval/README.md` is the doctrine.
- `lib/generators/poetry/` — the install surface (installer, per-adapter
  generators, the AGENTS/skills sections) and `block/templates/*.html.erb`,
  the canonical source of the eight blocks (docs previews render these
  files per request).
- `lib/poetry/ui/recipes.rb` — the recipes channel roster: registry
  items projected LIVE from gem-shipped sources
  (skills via the boot-free seams, scaffold .tt set, screen slices under
  `lib/generators/poetry/recipes/`). A recipe's files must be the same
  bytes a generator installs — never author recipe-only content except
  screen slices, and keep targets traversal-free (RecipeItems raises).
- `lib/poetry/ui/testing/` — the shipped interaction testers:
  `require "poetry/ui/testing"`, include `Poetry::Ui::Testing` in a Capybara
  system test, then drive components through their REAL keyboard/pointer
  contracts (`poetry_select("#plan").select_option("Pro", via: :keyboard)`;
  also `poetry_combobox`, `poetry_dropdown_menu`, `poetry_dialog`). Write consumer
  tests THROUGH the testers, never with hand-rolled click sequences — they
  assert on the data-open/aria contract, and `bundle exec rake test:testers`
  proves them against the live preview pages (browser-gated, like visual/axe).

## Component conventions

- Dictionaries carry mechanics; visual tokens live theme-side. A utility
  in a Ruby string beats every theme's rule at once (a classic sizing
  chain and a demo width once overrode nine themes) — the dictionary
  ledger now catches it, and two deliberate theme-side doctrines are
  protected by tests (the placeholder color rhea darkens for AA; the
  toggle's outline hover, which wins by rule order).
- Parts wear the source's `data-slot` vocabulary (the combobox's embedded
  engine is `combobox-*`, menus split `checkbox-item-indicator` /
  `radio-item-indicator`, the field's hint is `field-description`).
  `data-slot` is a public styling contract for host CSS — renaming one is
  a breaking change.
- An icon that is a part carries the part itself (`Icon::Component.new(name:,
  class: css(:part), data: { slot: … })`); never wrap an unsized icon in a
  span — it falls back to its 24px intrinsic box.
- Two ways to render a library component, chosen by who is authoring.
  Inside a component template (and its Ruby), render siblings by class —
  `render Poetry::Ui::Icon::Component.new(...)` — never through the
  `helpers` proxy: the `poetry_*` helpers are mixed into ActionView's
  base, not ViewComponent's, so `poetry_icon` is undefined here and
  `helpers.poetry_icon` couples the component to whatever view context
  is rendering (fine in a host page, wrong under an isolated render).
  The one sanctioned proxy use is a part that exists only as a helper
  (input-group addon/text/input, the table and sidebar parts, avatar
  and item groups). Host-side code — docs pages, previews, generated
  code, jumpstart overrides — uses the `poetry_*` helper: the registry,
  editor snippets, skills, and `poetry:check` key on helper names and
  do not parse `render Klass.new`. Instantiating a class in a host view
  is only for handing the instance to a sibling first (a Field's
  `control_attributes`).
- Stimulus wiring is declared in Ruby via the `use_stimulus` DSL (47
  components do); the StimulusContract gate verifies declarations against
  poetry-core's controllers manifest, and the registry / agent surface /
  docs all project from them — wire nothing by hand-writing `data-*`.
  Agent-callable actions are `tool` declarations after `use_stimulus`.
- `part` declares anatomy and every state a theme may style; the
  styled-state gate (`config/theme_states.yml`) fails a theme rule that
  styles a `data-*` state no part wearing that hook emits.
- DOM ids go through the StableId plumbing (`key:` derives dom_id-first,
  explicit `id:` wins); never mint bare random ids — keyed identity is
  what keeps Turbo morph and fragment caches honest (`poetry:check` warns
  on unkeyed components in loops and cache blocks).
- Utilities live where the harvest sees them: the template-class scan
  reads literal classes in templates, NOT strings interpolated from Ruby.
  Anything that must reach host safelists belongs in a Style dictionary
  element or a literal template attribute — an interpolated utility
  builds fine here and purges in every host.
- Templates must compile under `Herb::Engine` (`rake herb:compile`): no ERB
  output in an attribute NAME, no bare output in attribute position,
  `<%= tag.attributes(...) %>` only as the last thing before `>`.
- Every public object is documented (YARD floors at 0, `yard:verify` fails
  on warnings); declarations carry their docs (`doc:` on `option`/`style`
  and on `renders_one`/`renders_many`, whose `renders:` keyword takes the
  slot lambda so the doc reads first; `slot_doc` only for docs declared
  away from the declaration); template-facing methods are `@api private`.

## Known traps

- Kill CSS transitions/animations before cross-style computed reads;
  double-rAF is NOT settled. Tailwind v4's `translate-*` is the `translate`
  property, not `transform`.
- Tailwind box-shadow never computes "none" while ring/shadow var plumbing is
  live — parse layers and filter transparent zeros.
- Preview sidecars are class-level; variant axes must be `style` attributes,
  not `option`s.
- `render SomeComponent.new(...) { "text" }` binds the block to `.new`, not
  `render` — the content silently vanishes and the element paints empty
  while DOM checks stay green. Use the `poetry_*` helpers (or parenthesize
  `render(Component.new(...)) { }`). The eval's `links_have_accessible_names`
  gate exists because the judge caught exactly this.
- A source rule's fixed-pixel offset only fits the text size it was tuned
  for (the questionnaire's 1.8px indicator nudge assumed 14px text; the
  text-xs themes needed 0.25px) — re-check offsets when a theme changes a
  row's type size.

## Standing rules

Releases: versions move in lockstep across the family, with internal
dependencies pinned exactly (`= VERSION`); bumps happen only on the
maintainer's explicit go. Publishing runs only through the tag-triggered
release workflow (OIDC trusted publishing) — never `gem push` by hand. The
CHANGELOG stays bare until 0.1.0; commit messages carry the record.
Sibling gems ride local paths in the Gemfile only when checked out side by
side; the lockfile is not committed; the gemspec's dev-only list keeps
tooling, tests, docs, scripts, and the ledgers out of the gem.

Commit per logical change; registry, safelist, and design-export artifacts
are generated — regenerate, don't edit.

Naming: "Poetry" is the product in prose; gem names, constants, and
identifiers stay as they are.

Third-party code: adapt only from MIT-compatible sources (MIT/ISC/BSD;
Apache-2.0 carries its notice). Copyleft (GPL/LGPL/AGPL), restricted-use,
and commercial sources are patterns-and-ideas only — never code. Every
adaptation: a THIRD_PARTY_NOTICES.md section (upstream, license, adapted
files, full license text) — that file is the canonical attribution; the
source URL lives there, and upstream is never named in code. An
adaptation change that doesn't touch THIRD_PARTY_NOTICES.md is
incomplete.
