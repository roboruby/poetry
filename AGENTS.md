# AGENTS.md — poetry

The umbrella gem: one `gem "poetry"` installs the library proper —
poetry-core (the engine and component DSL), poetry-ui (the components,
themes, form builder, and agent surface), and poetry-lucide (the default
icon set) — as hard runtime dependencies, required outright in
`lib/poetry.rb`. poetry-charts, poetry-agent, poetry-extract, and
poetry-simple_form are opt-in gems a host adds itself. Almost all real work
happens in the sibling gems — check their own AGENTS.md files.

## Gates

- `bundle exec rake` — the default chain: `test` (the loader test proves all
  three siblings load through `require "poetry"`), `rubocop`, `yard:verify`
  (no YARD warnings), `yard:coverage` (every public object documented; the
  floor is 0).
- CI (`.github/workflows/main.yml`) runs that chain on Ruby 3.4 and 4.0 with
  the siblings resolved from RubyGems, plus `bundle-audit`. The release
  workflow (`release.yml`, tags `v*`) runs `rake version:verify_tag` (the tag
  must equal `v<VERSION>`), then publishes via OIDC.
- `rake "version:bump[X.Y.Z]"` edits the one VERSION constant.

## Standing rules

Releases: this gem's version and its three `= VERSION` pins move in
lockstep with the family; bumps happen only on the maintainer's explicit
go, and the umbrella publishes LAST (core, lucide, and ui must be live on
RubyGems first). Publishing runs only through the tag-triggered release
workflow (OIDC trusted publishing) — never `gem push` by hand. The
CHANGELOG stays bare until 0.1.0; commit messages carry the record.
Siblings ride local paths in the Gemfile only when checked out beside this
repo; the lockfile is not committed.

Never add a `rescue LoadError` around a sibling require — the umbrella is
not a shell; a missing dependency is a real failure.

Naming: "Poetry" is the product in prose; gem names, constants, and
identifiers stay as they are.
