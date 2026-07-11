# AGENTS.md — poetry-docs

The docs site and standing fresh-app install proof: a Rails app (importmap +
tailwindcss-rails + propshaft, no ActiveRecord, no Node) consuming the poetry
gems as path-pinned siblings. Gallery + Demos + `/theming` with the nine-theme
switcher.

## Commands

- `bin/rails test` — includes the whole-gallery gates (every catalog page
  must 200 AND carry ≥1 example)
- `bin/rails tailwindcss:build` — REQUIRED after any change that affects
  scanned classes (new pages, new examples, gem fragment changes)
- `ruby script/build_style_registry.rb` — regenerate the nine wrapped
  `.style-<name>` theme files after ANY gem fragment change, then rebuild CSS
- Dev server convention: port 4100 (`bin/rails server -p 4100 -d`;
  pid in `tmp/pids/server.pid`)

## Conventions

- Pages are registry-driven: add entries via DocsCatalog; the sidebar, ⌘K
  palette, and both whole-gallery gates pick new pages up automatically.
- Examples are self-contained partials riding the shared Preview/Code tabs;
  the example frame is ITSELF a line-variant poetry_tabs — scope any
  automated queries to the demo's own group, never the first
  `.cn-tabs-trigger` on the page.
- Exactly ONE `style-<name>` class lives on `<html>` at all times
  (server-rendered `style-default`, pre-paint localStorage swap). Never ship
  an unscoped visual theme layer.

## The one hard rule

**Never re-run `poetry:install` here.** It would re-inject the
`style-default.css` slot imports into the Tailwind entry, and an unscoped
visual layer leaks omitted-token defaults through the scoped style registry
(see the warning comment in `app/assets/tailwind/application.css`). To
refresh the AGENTS.md pointer section alone, use `bin/rails g poetry:agents`.

<!-- poetry:agents:begin -->
## Building UI with poetry (65 components + 13 chart components + 6 blocks)

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
  `["exec", "poetry-agent"]`) serves `compose`, `check`,
  `describe_component`, `list_components`, `list_blocks`, and
  `describe_block` from the live registry with no app boot - prefer
  `compose` to start and its `check` tool when iterating.
- One visual theme per app (chosen at install with `--theme`); components
  read tokens, never restate them.
- Claude Code skills: `poetry` (component contracts by family) and
  `poetry-design` (theme / compose / audit / study - the taste layer)
  live under `.claude/skills/` - load `poetry` whenever writing ERB,
  and `poetry-design` whenever composing a page or screen, BEFORE
  building (any page task is a design task, not only ones that
  mention design). Install/refresh: `bin/rails g poetry:skill`.
- Design interop: `bin/rails poetry:design:export` writes this app's
  DESIGN.md (tokens + treatment) for external design skills.
<!-- poetry:agents:end -->
