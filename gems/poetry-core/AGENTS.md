# AGENTS.md — poetry-core

The machinery gem: Stimulus controllers (overlay/focus/presence/popper and the
component machines), the token pipeline, and the shared contract
infrastructure (Registry, LlmsText, controllers manifest, `poetry check`
internals) the component gems build on.

## Gates

- `bundle exec rake test` — Ruby suite
- `npm test` — vitest (controller behavior + the drift gates:
  controllers_manifest, state_vocabulary, events_declaration)
- `npm run manifest` — regenerate `config/controllers_manifest.json` +
  `config/state_vocabulary.json` after any controller surface change
- `bundle exec rake registry:verify` / `tokens:verify` — generated-artifact
  drift (regen with the matching `:generate`)
- `bundle exec rubocop`

## Cross-repo render surface

poetry-ui compiles its preview stylesheet and copies its controllers FROM
THIS REPO at run time. Changes under `tokens/*.css`, `vendor/**`, or
`app/javascript/poetry/core/**` move poetry-ui's golden pixels with no
poetry-ui commit — this repo's gates never run that visual suite (a
code_block single-spacing fix once went out this way and left three goldens
stale for four days). After touching any of those paths, run poetry-ui's
`bundle exec rake test:visual` (Chrome) in the same working session and
re-bless deliberately if pixels moved; poetry-ui's `goldens:verify_inputs`
default-gate check will catch the drift there regardless, by hashing these
files against the manifest stamped at last bless.

## Design interop + slop rules (N14)

- `Poetry::Core::DesignMd` — DESIGN.md serialize/parse (google-labs front
  matter + canonical sections; round-trip byte-stable; foreign files via the
  tolerant section walker). `DesignMd::Import` plans token overrides with
  WCAG AA enforced on the merged set (nearest-AA = a deterministic OKLCH
  L-walk, chroma held) and DROP-not-fabricate for the rest.
- `Poetry::Core::DesignLint` — twelve deterministic design-slop rules
  (AST tier on the herb walk, ERB or plain HTML; DOM tier on computed
  styles). Warnings that name the fix; provenance cited per rule.

## Controller conventions

- State vocabulary is Base UI: bare boolean data attributes via
  `helpers/state.js` `setState` — never write `data-state="open"` style pairs.
- `static events = [...]` declares every event a controller dispatches, FULL
  names as emitted (`poetry:select:change`, `poetry--core--tabs:change`).
  `test/javascript/events_declaration.test.js` scans the source and fails on
  any undeclared or non-literal dispatch. The manifest, registry, and
  llms-full all render from the declaration.
- Subclasses (Drawer extends Dialog) get their statics merged up the class
  chain by the manifest — declare only what the subclass itself adds.
- The dommy tier runs controllers on QuickJS + a real DOM: no layout, no
  matchMedia (reports desktop), no Intl — server-feed what needs those.

## Known traps

The cross-repo trap ledger is kept outside this repo.
Highlights that recur: value callbacks fire async
(reflect synchronously in mutators); programmatic `.focus()` fires no
`focusin` in dommy; presence exits need per-value bookkeeping.

## Standing rules

The naming hold: never push, publish, or claim gems.

Third-party code: adapt or vendor only from MIT-compatible sources
(MIT/ISC/BSD; Apache-2.0 carries its notice). Copyleft (GPL/LGPL/AGPL),
restricted-use, and commercial sources are patterns-and-ideas only —
never code. Every adaptation gets a source URL in the file header AND a
THIRD_PARTY_NOTICES.md section (upstream, license, adapted files, full
license text); vendored assets keep their LICENSE next to the code under
vendor/. An adaptation PR that doesn't touch THIRD_PARTY_NOTICES.md is
incomplete.
