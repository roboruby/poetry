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
