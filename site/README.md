# poetry-docs

The documentation site for the **poetry** family — a Rails app that consumes
the gems exactly the way a real host does, and holds the component and chart
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
   sibling working trees. The seams the gem suites can only stub (importmap
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

Two bundles, one family:

- **Locally, the site runs the working trees.** When the poetry gems are
  checked out beside this repo (`../poetry-core`, `../poetry-ui`, ...),
  `config/boot.rb` selects `Gemfile.siblings`, and the docs describe the code
  as it is right now - nothing is pinned. `bin/setup` installs that bundle;
  `Gemfile.siblings.lock` stays out of git. Set `BUNDLE_GEMFILE=Gemfile` to
  run the pinned release on the same machine.
- **Everywhere else, the site runs the release.** `Gemfile` pins the family
  to the version in `.poetry-version` and its `Gemfile.lock` is committed, so
  CI, fresh clones and deploys resolve the published gems. CI runs `bin/ci`
  (setup, RuboCop, the gem and importmap audits, the tests) on that bundle,
  so it is the standing proof that the released gems install and render.

`test/poetry_version_test.rb` keeps the two honest: the loaded family must be
one version, a RubyGems bundle must match `.poetry-version`, and every
`data/api/*.json` must carry the version it was generated from.

## After a family release

```sh
echo 0.0.4 > .poetry-version
bundle lock                          # refresh the committed lockfile
bin/rails docs:refresh               # skills, API reference, search index
BUNDLE_GEMFILE=Gemfile bin/rails test   # the release, as CI runs it
```

This app carries no deploy configuration.

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
