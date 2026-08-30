# AGENTS.md — poetry-lucide

The default Poetry icon set: Lucide's SVGs vendored at a pinned
upstream commit, sanitized at vendor time, registered with poetry-core's
icon registry. 1,745 icons under `icons/` (plus the manifest recording the
pinned commit).

## Gates

- `bundle exec rake` — the default chain: `test`, `rubocop`, `yard:verify`,
  `yard:coverage` (every public object documented; floors at 0).

## Conventions

- Icons are updated ONLY via `script/fetch_icons.rb` (re-vendors at a new
  pinned commit SHA — never a mutable tag — and re-sanitizes: `<script>` and
  `<foreignObject>` removed, `<use>`/`<image>` with external hrefs removed,
  `on*` attributes stripped) —
  never hand-edit files under `icons/`. The SHA on disk is
  `icons/VENDORED_COMMIT`, exposed as `Poetry::Lucide.vendored_commit`.
- The vendored SVGs stay under Lucide's ISC license: `LICENSE-LUCIDE.txt`
  ships in the gem beside them and must survive any re-vendor (it also
  carries the MIT attribution for the 115 Feather-derived icons);
  `THIRD_PARTY_NOTICES.md` summarizes both. The gem's own code is MIT
  (`LICENSE.txt`).
- The icon count in the README is a checked claim — keep it equal to the
  SVGs on disk after a re-vendor.

## Standing rules

Releases: versions move in lockstep across the family, with internal
dependencies pinned exactly (`= VERSION`); bumps happen only on the
maintainer's explicit go. Publishing runs only through the tag-triggered
release workflow (OIDC trusted publishing) — never `gem push` by hand. The
CHANGELOG stays bare until 0.1.0; commit messages carry the record.
poetry-core rides a local path in the Gemfile only when checked out beside
this repo; the lockfile is not committed; `script/` never ships.

Naming: "Poetry" is the product in prose; gem names, constants, and
identifiers stay as they are.

Third-party code: this gem exists to vendor one MIT-compatible upstream.
Vendor only from MIT-compatible sources (MIT/ISC/BSD; Apache-2.0 carries
its notice) and keep the upstream license text shipping next to the
assets, with a THIRD_PARTY_NOTICES.md section for each.
