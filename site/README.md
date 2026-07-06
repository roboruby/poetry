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
bundle install
bin/rails tailwindcss:build   # or bin/dev for the watcher
bin/rails s
```

The poetry gems are **path-pinned to sibling checkouts**
(`../poetry-core`, `../poetry-lucide`, `../poetry-ui`, `../poetry-charts`)
while the naming hold stands — published names land once naming reopens.
For the same reason this app has **no deploy configuration** (no Kamal, no
Docker, no domain): build local, claim nothing.

## Re-running the installer

`bin/rails g poetry:install --charts` is idempotent — re-run it after gem
upgrades to pick up new tokens/safelist/vendored layers. `poetry:add
<Component>` copies components in under `app/components` if the site ever
needs to customize one (prefer not to — the site should show the gems as
shipped).
