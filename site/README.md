# poetry-docs

The documentation site for the **poetry** family — a Rails app that consumes
the gems exactly the way a real host does, and will grow the component +
chart galleries (the ui.shadcn.com parity showcase).

## Two jobs

1. **The docs site.** Component gallery, the 59-example chart gallery, the
   live demos (`live:`, `sync:`, windowing, Turbo morphs) — everything a
   static site cannot show, because the selling point is server-rendered
   SVG plus Hotwire behavior.
2. **The standing fresh-app install proof.** This app was wired by running
   the real installer — `bin/rails g poetry:install --charts` — against
   path-pinned gems. The seams the gem suites can only stub (importmap pin
   merging, safelist generation with the charts engine loaded, controller
   registration, the Tailwind entry) run for real here; `bin/rails test`
   asserts the smoke page still renders a poetry component and a finished
   chart SVG through that pipeline.

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
  CI, fresh clones and deploys resolve the published gems. CI is therefore
  the standing proof that the released gems install and render.

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

`bin/rails g poetry:install --charts` is idempotent — re-run it after gem
upgrades to pick up new tokens/safelist/vendored layers. `poetry:add
<Component>` copies components in under `app/components` if the site ever
needs to customize one (prefer not to — the site should show the gems as
shipped).
