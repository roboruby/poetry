# AGENTS.md — poetry-hugeicons

Hugeicons (the free set) as a Poetry icon set: vendored at a pinned upstream commit,
sanitized at vendor time, registered with poetry-core's icon registry as
`:hugeicons`. 6,137 icons, one packed file
per style under `icons/` plus `VENDORED_COMMIT`.

## Gates

- `bundle exec rake` — the default chain: `test`, `rubocop`, `yard:verify`,
  `yard:coverage` (every public object documented; floors at 0).

## Conventions

- Icons are updated ONLY via `script/fetch_icons.rb`, which re-vendors at
  a new pinned commit SHA (never a mutable tag) through
  `Poetry::Core::Icons::Vendor`. Never hand-edit `icons/`. The SHA on disk
  is `icons/VENDORED_COMMIT`, exposed as `Poetry::Hugeicons.vendored_commit`.
- Upstream names become Poetry icon names by one rule (`Fetcher#icon_name`:
  lowercase kebab-case, `+` as `-plus`, other characters dropped); when two
  files land on one name the already-clean file wins and the other is
  reported as skipped.
- The icon counts in the README are a checked claim; keep them equal to
  the packed files after a re-vendor.
- The vendored icons stay under their upstream license: `LICENSE-HUGEICONS.txt`
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

Third-party code: vendor only from MIT-compatible sources and keep the
upstream license text shipping next to the assets, with a
THIRD_PARTY_NOTICES.md section for each.
