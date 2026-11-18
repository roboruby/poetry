# AGENTS.md — poetry-solar

Solar Icon Set as a Poetry icon set: vendored at a pinned upstream commit,
sanitized at vendor time, registered with poetry-core's icon registry as
`:solar`, `:solar_bold`, `:solar_bold_duotone`, `:solar_broken`, `:solar_line_duotone`, `:solar_outline`. 8,706 icons, one packed file
per style under `icons/` plus `VENDORED_COMMIT`.

## Gates

- `bundle exec rake` — the default chain: `test`, `rubocop`, `yard:verify`,
  `yard:coverage` (every public object documented; floors at 0).

## Conventions

- Icons are updated ONLY via `script/fetch_icons.rb`, which re-vendors at
  a new pinned commit SHA (never a mutable tag) through
  `Poetry::Core::Icons::Vendor`. Never hand-edit `icons/`. The SHA on disk
  is `icons/VENDORED_COMMIT`, exposed as `Poetry::Solar.vendored_commit`.
- Upstream names become Poetry icon names by one rule (`Fetcher#icon_name`:
  lowercase kebab-case, `+` as `-plus`, other characters dropped); when two
  files land on one name the already-clean file wins and the other is
  reported as skipped.
- The icon counts in the README are a checked claim; keep them equal to
  the packed files after a re-vendor.
- The vendored icons stay under their upstream license: `LICENSE-SOLAR.txt`
  ships in the gem beside them, and
  `THIRD_PARTY_NOTICES.md` carries the text. The gem's own code is MIT
  (`LICENSE.txt`).

## Standing rules

Releases: versions move in lockstep across the family, with internal
dependencies pinned exactly (`= VERSION`); bumps happen only on the
maintainer's explicit go. Publishing runs only through the tag-triggered
release workflow (OIDC trusted publishing) — never `gem push` by hand.
poetry-core rides a local path in the Gemfile only when checked out beside
this repo; the lockfile is not committed; `script/` never ships.

Naming: "Poetry" is the product in prose; gem names, constants, and
identifiers stay as they are.

Licensing: this gem is the family's one exception to MIT-compatible
vendoring, approved by the maintainer. The icons are 480 Design's, under
CC BY 4.0, which has no ShareAlike term, so nothing else changes license.
CC BY 4.0 requires a credit on every copy, and the gem carries it three
ways: `Poetry::Solar::ATTRIBUTION`, which the Icon component renders as a
comment inside every svg; `NOTICE` (creator, source, license, the changes
made); and `LICENSE-SOLAR.txt`, the license text. Never remove or shorten
any of them, never strip comments from these icons, and keep
`spec.licenses = ["MIT", "CC-BY-4.0"]`. If 480 Design asks for the credit to
be removed, that request wins. A change to how the icons are modified
updates the NOTICE and ATTRIBUTION in the same commit.
