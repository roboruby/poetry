## [Unreleased]

- `poetry:install --charts` — one-shot poetry-charts wiring for hosts
  carrying the gem: copies the motion stylesheet into the Tailwind entry
  (tailwindcss-rails compiles standalone, so a gem-path @import cannot
  resolve) and registers the chart controllers in the Stimulus index,
  riding the same idempotent primitives as the core wiring. Fails fast
  with a Gemfile hint when poetry-charts is absent. The safelist pass
  already covers the chart dictionaries on its own (they subclass
  Poetry::Core::Style), and the charts engine merges its own importmap
  pins — the flag adds exactly the two wires the engine cannot.

- DropdownMenu — the menus-family ANCHOR:
  the full item union (item/checkbox/radio-group/label/separator/group/
  recursive sub) as one ordered polymorphic slot collection, a typed
  poetry-Button trigger owning the aria-haspopup/expanded/controls wiring,
  and two Builder-wired hosts (root: poetry--core--menu + popper; content:
  layer controllers token-ACTIVATED by the controller on open — never
  server-rendered). Source-exact new-york-v4 classes; each sub is its own
  popper instance (side flips under dir: :rtl); duplicate radio values
  raise; shortcut is a visual, aria-hidden hint. Ships the `menu` eval
  task pair, a dommy-tier behavior test (click/keyboard open, focus per
  data-open-reason, select-close), and the popper var alias shim in
  poetry-core's utilities layer binding the source-exact
  --radix-dropdown-menu-content-* names to --radix-popper-*.
- Button (the contract reference component every later component
  follows) + the minimal Icon (pulled forward) - the first components, built
  entirely on poetry-core's public DSL (the dogfooding guarantee).
- The thinnest eval slice — `rake eval:scorecard` renders
  frozen arms (poetry vs a realistic raw-Tailwind generation) through
  deterministic gates split cross-arm vs poetry-only (the A/B honesty rule)
  and emits the first scorecard. First result: poetry 5/5, raw 2/5.
- Previews for every component (the variant matrix; smoke-rendered in
  CI and coverage-asserted against the declared variants); `llms.txt` +
  `llms-full.txt` served by the engine, generated live from the registry;
  `rails g poetry:agent_rules` — the two-file ruleset (gem-owned
  agent-rules.md force-refreshed from the registry + user-owned
  house-rules.md seeded once) with idempotent marker-import into
  CLAUDE.md/AGENTS.md (detect-but-never-rewrite on broken markers).
- Icon reworked onto the pluggable icon-set registry — the full
  Lucide set via poetry-lucide (1745 icons, pinned SHA, sanitized at vendor
  time), `config.icon_library` swap + per-render `library:` override.
- Link, Badge, Card, Alert — shadcn new-york-v4 parity (Link is
  poetry's own navigation contract; shadcn ships none). Alert carries the
  a11y the reference lacks (role=alert/status by severity — the original
  motivating bug) with a typed icon slot; Card composes via
  data-slot; every component ships agent rules + previews and renders in
  both css modes. Dialog + the deeper primitives are the next entry.
- The Dialog — the depth-moat overlay on the PLATFORM trap
  (native <dialog>/showModal owns focus trap, Esc, top-layer, focus
  return; the poetry--core--dialog controller adds data-state, backdrop
  dismissal, dismissible: false, and the scroll lock). Typed Button
  trigger slot, REQUIRED title (aria-labelledby always wired, unique per
  instance), i18n'd icon-only close button.
- The forms foundation — Input + Label + Field (the error quartet:
  label/control/hint/error with auto aria-describedby via
  Field#control_attributes) + Poetry::Ui::FormBuilder (`form.field(:email)`:
  i18n labels from human_attribute_name, model errors auto-flow to
  aria-invalid + the error paragraph, presence validators become
  aria-required ONLY — never the native attribute).
- The distribution generators — `poetry:install` (tokens + @theme +
  live-generated safelist into the host's Tailwind entry, idempotent
  injection; initializer; manifest), `poetry:add Component` (copy-in with
  recursive dependency resolution; existing files SKIPPED — local edits
  win; version provenance recorded in config/poetry_components.yml), and
  the `poetry:verify` host-app rake task (the Verifier + herb
  gates in the consumer's app, graceful when tools are absent).
