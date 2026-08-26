# AGENTS.md — poetry-docs

The docs site and standing fresh-app install proof: a Rails app (importmap +
tailwindcss-rails + propshaft, sqlite-backed demo data, no Node) consuming the
poetry gems as path-pinned siblings. Gallery + Demos + the blocks catalog +
`/theming` with the nine-theme switcher + guide pages (installation, forms,
pagination, typography, optimistic-forms, editors).

## Commands

- `bin/rails test` — includes the whole-gallery gates (every catalog page
  must 200 AND carry ≥1 example)
- `bin/rails tailwindcss:build` — REQUIRED after any change that affects
  scanned classes (new pages, new examples, gem fragment changes)
- `ruby script/build_style_registry.rb` — regenerate the nine wrapped
  `.style-<name>` theme files after ANY gem fragment change, then rebuild CSS
- Dev server convention: port 4100 (`bin/rails server -p 4100 -d`;
  pid in `tmp/pids/server.pid`). `bin/dev` needs a real terminal —
  `tailwindcss:watch` exits immediately without a TTY and foreman then
  kills every Procfile process; headless sessions run
  `bin/rails tailwindcss:build` once + `bin/rails server` instead

## Conventions

- Pages are registry-driven: add entries via DocsCatalog; the sidebar, ⌘K
  palette, and both whole-gallery gates pick new pages up automatically.
- Examples are self-contained partials riding the shared Preview/Code tabs
  (+ an "Open standalone" link per frame: /examples/:section/:slug/:name,
  and /examples/blocks/:slug for blocks - viewport-scale, no containment recipes
  renders just the partial in the bare `example` layout; the two
  data-dependent sets — pagination guide, interactive demo — share their
  prep via the ExampleData concern so it can't fork);
  the example frame is ITSELF a line-variant poetry_tabs — scope any
  automated queries to the demo's own group, never the first
  `.cn-tabs-trigger` on the page.
- Exactly ONE `style-<name>` class lives on `<html>` at all times
  (server-rendered `style-default`, pre-paint localStorage swap). Never ship
  an unscoped visual theme layer.
- The Chat Replay demo is the deterministic replay rig: Poetry::Ui::Chat frames stream
  as versioned vreplace Turbo Streams over SSE (ChatReplayController;
  the custom action in application.js applies only strictly-newer
  data-version frames). State is entirely URL params - streams must stay
  byte-identical per URL, and the closing batch must remove the
  turbo-stream-source (SSE reconnects replay otherwise).
- Every docs page serves a markdown mirror - append `.md` to its URL or
  send `Accept: text/markdown`. Controllers implement `markdown_mirror`
  (the MarkdownMirror concern serves it on either signal; a page without
  one answers 406, never a MissingTemplate 500). Discovery surfaces: root
  `/llms.txt` (DocsCatalog-generated, `/llms-full.txt` redirects into the
  engine), `/openapi.json` + `/.well-known/api-catalog`, skills at
  `/.well-known/skills/` (with an `agent-skills` alias); HTML pages
  advertise their twin via `<link rel="alternate">` + the HTTP `Link`
  header. robots.txt and `/sitemap.xml` are DYNAMIC (MachineController) -
  absolute URLs derive from the request host since the naming hold means
  no fixed domain; robots carries Content-Signal + the sitemap pointer. A new machine endpoint gets an ENDPOINTS row in
  MachineController - the openapi test GETs every documented path, so the
  description can't drift into a document that lies.

## The one hard rule

**Never re-run `poetry:install` here.** It would re-inject the
`style-default.css` slot imports into the Tailwind entry, and an unscoped
visual layer leaks omitted-token defaults through the scoped style registry
(see the warning comment in `app/assets/tailwind/application.css`). To
refresh the AGENTS.md pointer section alone, use `bin/rails g poetry:agents`.

<!-- poetry:agents:begin -->
## Building UI with poetry (87 components + 13 chart components + 8 blocks)

- FIRST MOVE on any UI brief: call the poetry MCP `compose` tool with the
  task text, before writing any ERB. It routes to the matching vetted
  block (source included, adapt in place - the winning path for screens)
  or to the right components. No MCP? `bin/rails g poetry:block --list`
  and start from the closest block. Composing a screen from scratch when
  a block matched is the known losing path.
- Compose with the `poetry_*` helpers; never hand-write `cn-*` classes, raw
  hex/oklch colors, or off-scale arbitrary values - tokens and variants carry
  the design.
- Machine catalog: `/poetry/llms.txt` (index + blocks) and `/poetry/llms-full.txt`
  (full contracts + Stimulus wiring: targets / values / actions / events).
- Check comes LAST: `bin/rails poetry:check` as the FINAL action, after
  the last edit (unknown components/slots/variants/wiring, icon names,
  enum values, typed-slot props, helper + setter arity, yield-less
  blocks, setter keywords, required content blocks, required slots,
  did-you-mean, `--json`; needs the `herb` gem in the Gemfile). An edit
  made after your last check is unverified markup - re-run it.
- Faster: the `poetry` MCP server (`.mcp.json`: command `bundle`, args
  `["exec", "poetry-agent"]`, the poetry-agent gem) serves ten tools from the live registry
  with no app boot - `compose`, `build_page`, `list_components`,
  `describe_component`, `check`, `list_blocks`, `describe_block`,
  `list_recipes`, `get_skill`, and `guidance`. Prefer `compose` (or `build_page` for a
  whole screen) to start, and its `check` tool when iterating. Wire it
  into every editor at once with `bin/rails g poetry:editor` (MCP
  configs for VS Code / Cursor / Claude Code / Zed / RubyMine plus
  registry-driven snippets).
- Browser agents (WebMCP): opt a rendered component into the user's own
  agent with `webmcp: "name"` on the helper call - Combobox, Dialog, Sheet,
  Drawer, and Tabs declare tools (`describe_component` at `full` lists them);
  declare a form as a tool with `poetry_webmcp_form(tool: { name:,
  description: })` (autosubmit is GET-only). Needs the poetry-agent gem and
  `registerPoetryAgent(application)`; `poetry:check` gates the opt-ins.
- One visual theme per app (chosen at install with `--theme`); components
  read tokens, never restate them.
- Component identity: pass `key:` (a record, or a literal string) on any
  poetry component inside a collection loop, a fragment-cache block, or
  a broadcast partial - keyed ids follow the record across Turbo morph
  reorders and stay stable inside cached fragments, where random ids
  force replacement. `key: record` derives via dom_id (a host `to_key`
  override propagates); explicit `id:` wins outright; repeated NEW
  records need explicit keys. `poetry:check` warns on unkeyed
  components in cache blocks and loops. Full story: the Stable IDs guide on the poetry docs site.
- Upgrading poetry gems: after `bundle update`, re-run
  `bin/rails g poetry:install` - the vendored token/theme/safelist
  files refresh (the installed theme sticks; `--theme` switches),
  new wiring appends, this section and the skills regenerate. Then
  rebuild CSS and run the suite. `bin/rails g poetry:diff` reports
  where copied-in components drift from the installed gems.
- `bin/rails g poetry:scaffold_templates` retargets the STANDARD
  `rails g scaffold` to emit poetry-composed views (DataTable index
  with URL state, Field-composed forms) plus a matching controller -
  prefer scaffolding over hand-writing CRUD views.
- Claude Code skills: `poetry` (component contracts by family),
  `poetry-design` (theme / compose / audit / study / figma / paper -
  the taste layer), and `poetry-component` (anatomy / documentation /
  audit - the authoring layer) live under `.claude/skills/` - load
  `poetry` whenever writing ERB, `poetry-design` whenever composing a
  page or screen, BEFORE building (any page task is a design task,
  not only ones that mention design), and `poetry-component` whenever
  authoring or reviewing an app-owned component. Install/refresh:
  `bin/rails g poetry:skill`.
- Design interop: `bin/rails poetry:design:export` writes this app's
  DESIGN.md (tokens + treatment) for external design skills.
- Overriding the theme: token-level restyling goes through
  `poetry:design:import` (design-overrides.css) - which also ingests a
  Figma variables export (`bin/rails poetry:figma:import[export.json]`)
  or a Paper "Copy theme" (`bin/rails poetry:paper:import[theme.css]`),
  dropping any swatch that fails WCAG AA. Host CSS that targets
  theme-owned `cn-*` classes is allowed ONLY as a declared
  override - a dated, reasoned entry under `overrides:` in
  config/poetry_components.yml (`bin/rails poetry:design:overrides`
  reports drift and prints the paste-ready declaration). Declare
  only after the user confirms intent; never declare to skip a fix.
<!-- poetry:agents:end -->
