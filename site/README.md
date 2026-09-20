# poetryui.com

The documentation site for the **poetry** family, under `site/` in the
family's repository — a Rails app that consumes the gems from `../gems`
exactly the way a real host does, and holds the component and chart
galleries, the guides, and the live demos.

## Two jobs

1. **The docs site.** A page per component and per chart with runnable
   examples, the guides (installation, forms, theming, testing, the agent
   surfaces), and the live demos (`live:`, `sync:`, windowing, Turbo morphs)
   — everything a static site cannot show, because the selling point is
   server-rendered SVG plus Hotwire behavior. The counts the site quotes
   about itself come from the registry, never from prose.
2. **The standing fresh-app install proof.** This app was wired by running
   the real installer — `bin/rails g poetry:install --charts` — against the
   gems in this repository. The seams the gem suites can only stub (importmap
   pin merging, safelist generation with the charts engine loaded, controller
   registration, the Tailwind entry) run for real here; `bin/rails test`
   asserts a component page and a chart page still render through that
   pipeline, finished SVG included.

## What the site serves besides pages

Every page has a markdown mirror (append `.md`, or send
`Accept: text/markdown`). Agents get `/llms.txt`, the component registry at
`/r/registry.json` (install with `bin/rails g poetry:add <name>`), the
installable skills under `/.well-known/skills` and `/agent-skills`, the
site's read-only MCP server at `/mcp`, and `/openapi.json` with its
`/.well-known/api-catalog`.

## Running it

```sh
bin/setup            # installs, prepares the databases, starts bin/dev
```

One bundle, one family: the Gemfile takes the poetry gems from `../gems`
by path, so the docs always describe the code beside them and nothing is
pinned. The lockfile is committed, which is what lets a deploy build the
image with `BUNDLE_DEPLOYMENT` on. CI runs `bin/ci` (setup, RuboCop, the
gem and importmap audits, the tests) on that bundle, so every push proves
the tree installs and renders, and the reference-data job checks that
`data/api/*.json`, the skills and the search index match the gems they
were generated from.

## After a family release

Nothing, here. The release train's bump stamps the version into the
family, re-locks this app on the new versions and runs
`bin/rails docs:refresh` (skills, API reference, search index) in the same
commit. Production is built from the release tag by the deploy
repository, which holds every hosting detail; this app carries no deploy
configuration.

## Re-running the installer

`bin/rails g poetry:install --charts` re-wires the app after gem upgrades
(new tokens, safelist entries, vendored layers). It is interactive by
design: it asks before overwriting hand-annotated files such as
`config/poetry_components.yml`, so answer per file and never pass
`--force`. The generated artifacts that need no judgment — the skills, the
API reference, the search index — regenerate together with
`bin/rails docs:refresh`. `poetry:add <Component>` copies a component in
under `app/components` if the site ever needs to customize one (prefer not
to — the site should show the gems as shipped).
