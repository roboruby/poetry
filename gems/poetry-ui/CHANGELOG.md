## [Unreleased]

- M3.5: the golden Button (the v2 contract reference component) + the
  minimal Icon (pulled forward from M5) - the first components, built
  entirely on poetry-core's public DSL (the dogfooding guarantee).
- M3.5: the thinnest eval slice — `rake eval:scorecard` renders
  frozen arms (poetry vs a realistic raw-Tailwind generation) through
  deterministic gates split cross-arm vs poetry-only (the A/B honesty rule)
  and emits the first scorecard. First result: poetry 5/5, raw 2/5.
- M4: previews for every component (the variant matrix; smoke-rendered in
  CI and coverage-asserted against the declared variants); `llms.txt` +
  `llms-full.txt` served by the engine, generated live from the registry;
  `rails g poetry:agent_rules` — the two-file ruleset (gem-owned
  agent-rules.md force-refreshed from the registry + user-owned
  house-rules.md seeded once) with idempotent marker-import into
  CLAUDE.md/AGENTS.md (detect-but-never-rewrite on broken markers).
- M5: Icon reworked onto the pluggable icon-set registry — the full
  Lucide set via poetry-lucide (1745 icons, pinned SHA, sanitized at vendor
  time), `config.icon_library` swap + per-render `library:` override.
- M6a: Link, Badge, Card, Alert — shadcn new-york-v4 parity (Link is
  poetry's own navigation contract; shadcn ships none). Alert carries the
  a11y the reference lacks (role=alert/status by severity — the original
  vcplus motivating bug) with a typed icon slot; Card composes via
  data-slot; every component ships agent rules + previews and renders in
  both css modes. Dialog + the P1–P3 primitives are M6b.
- M6b: the Dialog — the depth-moat overlay on the PLATFORM trap (:
  native <dialog>/showModal owns focus trap, Esc, top-layer, focus
  return; the poetry--core--dialog controller adds data-state, backdrop
  dismissal, dismissible: false, and the scroll lock). Typed Button
  trigger slot, REQUIRED title (aria-labelledby always wired, unique per
  instance), i18n'd icon-only close button.
