# Installing Poetry in a Rails app - agent instructions

Concise, imperative setup for a coding agent adding Poetry to a Rails 8 app
(importmap + tailwindcss-rails). The human guide is at `/installation`; this
file is the copy-and-follow version.

## Requirements

- Ruby >= 3.3, Rails ~> 8.0
- Tailwind CSS v4 via `tailwindcss-rails` (standalone CLI; no Node required)
- Stimulus >= 3.2 (importmap is fine; no build step needed)

## 1. Add the gems

```ruby
# Gemfile
gem "poetry-core"
gem "poetry-ui"
gem "poetry-lucide"        # default icon set; most components render an icon
gem "poetry-agent"         # the poetry-agent MCP server exe + the WebMCP runtime
# gem "poetry-charts"      # optional: server-rendered SVG charts
```

Then `bundle install`. (The gem named `poetry` is a name-reservation stub -
do not install it as the entry point; `poetry-core` + `poetry-ui` are the
library.)

## 2. Run the installer (idempotent - it is also the upgrade path)

```bash
bin/rails g poetry:install --theme default   # themes: default vega nova mira rhea maia luma lyra sera
bin/rails tailwindcss:build                  # or bin/dev
```

It vendors the token/theme CSS under `app/assets/tailwind/poetry/`, injects
the Tailwind `@import` lines, registers the Stimulus controllers, mounts the
engine (`/poetry/llms.txt`), and writes the `AGENTS.md` section and the Claude
Code skills.

If `app/javascript/controllers/index.js` is absent, register the controllers
yourself:

```js
import { registerPoetryControllers } from "@poetry/controllers"
import { registerPoetryAgent } from "@poetry/agent"
registerPoetryControllers(application)
registerPoetryAgent(application)   // WebMCP: rendered components' tools for the user's browser agent
```

For pre-paint dark mode, put `poetry_color_scheme_script` in your layout
`<head>`.

## 3. Render a component

```erb
<%= poetry_button(variant: :default) { "Save" } %>
```

Every component has a `poetry_<name>` helper. Compose through helpers,
variants, and theme tokens - never hand-write `cn-*` classes or raw
hex/oklch (`poetry check` flags it).

## 4. Own a component (optional)

```bash
bin/rails g poetry:add button dialog    # copies source into app/components; yours to edit
bin/rails g poetry:block app-shell      # a composed-screen starting point
```

Restart the server after `poetry:add` so the local copies take precedence.

## 5. Wire the agent surface

```bash
bin/rails g poetry:editor               # MCP configs + snippets for your editors (see /editors)
```

Or add the MCP server by hand:

```json
{ "mcpServers": { "poetry": { "command": "bundle", "args": ["exec", "poetry-agent"] } } }
```

When composing with the MCP: call `compose` FIRST, build from primitives, and
run `check` LAST (a PASS verdict, not an eyeball). `bin/rails poetry:check`
lints ERB against the contracts (needs `gem "herb"`).

## 6. Bring a design in (optional)

```bash
bin/rails poetry:figma:import[variables.json]   # a Figma variables export -> AA-gated theme
bin/rails poetry:paper:import[paper-theme.css]  # a Paper "Copy theme"     -> AA-gated theme
```

Swatches that fail WCAG AA are dropped and reported, never shipped.

## Upgrading

`bundle update` upgrades gem-owned code; re-run `bin/rails g poetry:install`
to refresh the vendored CSS/safelist (your theme choice sticks). `bin/rails g
poetry:diff` reports where your copy-ins stand.
