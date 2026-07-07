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
