# poetry-ui

Server-rendered UI components for Rails — the shadcn/ui component set as
ViewComponents on Stimulus, with nine complete visual themes, a
machine-readable component registry, and a full agent surface (llms.txt,
MCP, Claude Code skills, `poetry check`). Names are working titles; the
gems are unpublished.

## Install

```ruby
# Gemfile
gem "poetry-core"
gem "poetry-ui"
# gem "poetry-charts"   # optional
```

```bash
bundle install
bin/rails g poetry:install --theme default   # or vega, nova, mira, rhea, maia, luma, lyra, sera
```

The installer wires everything a host needs: the vendored token/theme CSS
set under `app/assets/tailwind/poetry/`, the Tailwind entry imports, the
class safelist, Stimulus controller registration, the engine mount
(llms.txt), an `AGENTS.md` section, and the Claude Code skills. Every step
is idempotent — file creations skip what exists, injections append only
missing lines, and the section/skills refresh in place.

Add `--charts` to wire poetry-charts (requires the gem in the bundle).

## Upgrade

**The install generator is the upgrade path, not a one-shot.** After
bumping the gems, re-run it:

```bash
bundle update poetry-core poetry-ui poetry-charts
bin/rails g poetry:install     # your theme choice sticks; --theme switches
bin/rails tailwindcss:build    # or your CSS build
bin/rails test                 # confirm the app still renders
```

The re-run refreshes what only it can refresh: the vendored CSS files
(new components ship their theme rules there) and the safelist (new
classes would otherwise be purged), plus any new wiring lines, the
AGENTS.md section, and the skills. Gem-owned code — components, templates,
Stimulus controllers, the registry and MCP surface — upgrades with
`bundle update` alone.

Copied-in code is yours and is never rewritten. To see where your copies
stand against the gems you now have installed:

```bash
bin/rails g poetry:diff        # read-only drift report for copy-ins
bin/rails g poetry:add <name>  # adds newly-shipped files, never overwrites
```

Three ownership tiers, three upgrade behaviors:

| Tier | Examples | Upgrades via |
|---|---|---|
| Gem-owned | components, controllers, registry, MCP | `bundle update` |
| Vendored into the app | `app/assets/tailwind/poetry/*`, safelist | re-run `poetry:install` |
| App-owned copy-ins | `poetry:add` components, blocks, `base.css`, initializer | you — `poetry:diff` reports |

## Agent surface

`/poetry/llms.txt` and `/poetry/llms-full.txt` (engine routes), the
`poetry` MCP server (`bundle exec poetry-agent`, boot-free), `bin/rails
poetry:check` (template verification — run it last), and the `poetry` /
`poetry-design` Claude Code skills. See the generated `AGENTS.md` section
in your app.

## License

MIT
