# AGENTS.md — poetry-core

The machinery gem: Stimulus controllers (overlay/focus/presence/popper and the
component machines), the token pipeline, the design interop (DESIGN.md
serialize/parse/import, DesignLint), and the shared contract infrastructure
(Registry, LlmsText, controllers manifest, the part/stimulus/agent-tool
contracts, `poetry check` internals) the component gems build on. The MCP
server lives in poetry-agent; core keeps the `tool` DSL it projects.

## Gates

- `bundle exec rake` — the default chain: `test`, `rubocop`, `tokens:verify`,
  `registry:verify`, `herb:compile`, `yard:verify`, `yard:coverage`. Green
  before every commit.
- `npm test` — vitest (controller behavior + the drift gates:
  controllers_manifest, state_vocabulary, events_declaration).
- `npm run manifest` — regenerate `config/controllers_manifest.json` +
  `config/state_vocabulary.json` after any controller surface change.
- Generated artifacts regenerate with the matching task: `tokens:generate`
  (tokens/*.css + the DESIGN.md front matter), `registry:generate`.
- CI (`.github/workflows/main.yml`) adds `bundle-audit`, the Herb linter
  (`rake herb:lint`, rules pinned in `.herb.yml`), and the vitest suite.

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

## Templates and documentation

- Templates must compile under `Herb::Engine` (`rake herb:compile`): no ERB
  output in an attribute NAME (`data-<%= state %>=""` → static names under
  control flow), no bare output in attribute position, and
  `<%= tag.attributes(...) %>` only as the last thing before `>`. Docs
  heredoc samples escape `<%` openers as well as closers.
- Every public object is documented; the YARD floors are 0 and
  `yard:verify` fails on any warning. Declarations carry their own docs
  (`doc:` on `option`/`style` and on `renders_one`/`renders_many` - the
  `renders:` keyword takes the slot lambda so the doc reads first;
  `slot_doc` only for docs declared away from the declaration) and the
  registry projects them. Template-facing methods are `@api private`; the
  handler kit in `yard/poetry_yard.rb` parses the declarative surfaces.

## Design interop + slop rules

- `Poetry::Core::DesignMd` — DESIGN.md serialize/parse (front
  matter + canonical sections; round-trip byte-stable; foreign files via the
  tolerant section walker). `DesignMd::Import` plans token overrides with
  WCAG AA enforced on the merged set (nearest-AA = a deterministic OKLCH
  L-walk, chroma held) and DROP-not-fabricate for the rest.
- `Poetry::Core::DesignLint` — twenty-three deterministic design-slop
  rules: nineteen on the Herb AST (ERB or plain HTML, the motion floor
  among them), four on computed styles. Warnings name the fix; provenance
  cited per rule.

## Contracts

- `use_stimulus` declares a component's wiring; `StimulusContract.verify`
  gates every declaration against the controllers manifest and the rendered
  previews (both component gems run it). The registry, agent surface, and
  docs all project from the declaration.
- `part` declares anatomy and states; `PartContract.verify` reconciles the
  declarations against rendered previews both ways. Ownership climbs to the
  nearest `data-component` root, with one exception: another component's
  root wearing a part the outer declares (an icon rendered as the indicator
  glyph) belongs to the outer.
- `tool` declares an agent-callable action in MCP `Tool` shape; `executes:`
  resolves through `stimulus_action` against the declared controllers and
  the manifest at CLASS LOAD, so declare `use_stimulus` before `tool`. The
  registry and llms-full list declared tools; `poetry check` carries the
  WebMCP rules; poetry-agent registers them at runtime.

## Controller conventions

- State vocabulary is Base UI: bare boolean data attributes via
  `helpers/state.js` `setState` — never write `data-state="open"` style pairs.
- `static events = [...]` declares every event a controller dispatches, FULL
  names as emitted. Component-facing events use the `poetry:<component>:<event>`
  namespace (`poetry:select:change`, `poetry:tabs:change`); layer/utility
  controllers (dismissable, focus-scope, roving-focus, hotkey) keep the
  identifier prefix (`poetry--core--dismissable:dismiss`).
  `test/javascript/events_declaration.test.js` scans the source and fails on
  any undeclared or non-literal dispatch. The manifest, registry, and
  llms-full all render from the declaration.
- Doc comments: file/class narration stays `//`; every PUBLIC method (and
  every exported helper function/constant) carries a JSDoc `/** ... */`
  block with `@param`/`@returns` - hard-private `#` members stay `//`.
  Because the events scan reads RAW SOURCE, no comment anywhere in a
  controller may quote a dispatch call or its option tokens - name events
  in prose instead ("dispatches poetry:select:change").
- Comments carry poetry's rules, never other libraries' names or
  anonymous "upstream" comparisons - attribution lives in
  THIRD_PARTY_NOTICES.md alone, and adapted files carry the generic
  pointer sentence.
- Subclasses (Drawer extends Dialog) get their statics merged up the class
  chain by the manifest — declare only what the subclass itself adds.
- Component DOM ids derive through `Poetry::Core::StableId` (`key:` →
  dom_id-first token, explicit `id:` wins) so Turbo morph pairs identity
  across renders and cached fragments stay composable — never mint bare
  random ids in components.
- `html_attributes` SETS the resolved class (the caller's classes merged
  once through the dictionary); never merge a class back over the caller's
  original.
- The dommy tier runs controllers on QuickJS + a real DOM: no layout, no
  matchMedia (reports desktop), no Intl — server-feed what needs those.

## Known traps

Traps that recur across controllers: value callbacks fire async
(reflect synchronously in mutators); programmatic `.focus()` fires no
`focusin` in dommy; presence exits need per-value bookkeeping.

## Standing rules

Releases: versions move in lockstep across the family, with internal
dependencies pinned exactly (`= VERSION`); bumps happen only on the
maintainer's explicit go. Publishing runs only through the tag-triggered
release workflow (OIDC trusted publishing) — never `gem push` by hand. The
CHANGELOG stays bare until 0.1.0; commit messages carry the record.
Sibling gems ride local paths in the Gemfile only when checked out side by
side; the lockfile is not committed; the gemspec's dev-only list keeps
tooling, tests, docs, and the ledgers out of the gem.

Naming: "Poetry" is the product in prose; gem names, constants, and
identifiers stay as they are.

Third-party code: adapt or vendor only from MIT-compatible sources
(MIT/ISC/BSD; Apache-2.0 carries its notice). Copyleft (GPL/LGPL/AGPL),
restricted-use, and commercial sources are patterns-and-ideas only —
never code. Every adaptation notes "Adapted from an MIT-licensed source
(source and license in THIRD_PARTY_NOTICES.md)" in its class doc AND
gets a THIRD_PARTY_NOTICES.md section (upstream, license, adapted files,
full license text) — the source URL lives there, never in code; vendored
assets keep their LICENSE next to the code under vendor/. An adaptation
PR that doesn't touch THIRD_PARTY_NOTICES.md is incomplete.
