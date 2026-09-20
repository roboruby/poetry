# AGENTS.md — poetry

This repository is the Poetry family: the umbrella gem at the root, the seven
gems under `gems/`, the poetryui.com site under `site/`, and the release
tooling under `tools/releaser/`. Each gem keeps its own AGENTS.md, bundle,
tests and gates; read the gem's file before working in it.

## Layout

- `gems/poetry-core`, `poetry-lucide`, `poetry-charts`, `poetry-extract`,
  `poetry-ui`, `poetry-agent`, `poetry-simple_form` — one directory per gem;
  siblings resolve by relative path (`../poetry-core`) inside the tree.
- `site/` — the docs app on the family from the tree (`../gems/*`), lock
  committed; a deploy builds from the release tag.
- `tools/releaser/` — versions, changelog dates, notes, build, sign, verify,
  push; its own small bundle and tests.
- The root: the umbrella gem (`poetry.gemspec`, `lib/`, `test/`) plus
  `VERSION`, the single source of truth for all eight gems. One
  `gem "poetry"` installs core, ui and lucide as hard runtime dependencies,
  required outright in `lib/poetry.rb`; charts, agent, extract and
  simple_form are opt-in gems a host adds itself.

## Gates

- In a gem directory, `bundle exec rake` runs its default chain. At the
  root, `bundle exec rake` runs the umbrella's own chain (`test`, `rubocop`
  by explicit file list, the YARD gates) and `bundle exec rake family` runs
  every gem's chain in publish order, then `site/bin/ci`, then this one.
- CI (`.github/workflows/ci.yml`) runs every gem on Ruby 3.4 and 4.0 from
  its own directory, the JavaScript and Herb checks, `bundle-audit` per
  bundle, the site, the reference-data freshness check and the releaser's
  tests; `all-green` is the one status for branch rules.
- RuboCop: there is deliberately no `.rubocop.yml` at the root. RuboCop
  merges a higher-level config's `Exclude` into every subproject, so a root
  exclusion silently empties the gems' lints. The umbrella lints from
  `.rubocop-umbrella.yml` by explicit paths.

## Releases

- `VERSION` at the root. `tools/releaser`'s `versions` task stamps every
  `version.rb`, `package.json` and `package-lock.json` and re-locks the
  site; the bump also runs the site's `docs:refresh`, because the reference
  data carries the version. `changelog:date` dates each gem's `## [X]`
  heading or inserts a no-changes section.
- The train tags `vX` (annotated) and opens a draft GitHub release with
  notes assembled from the eight changelogs. Publishing that release is the
  word: `release.yml` builds all eight reproducibly from the tag's commit
  time, signs each with sigstore, verifies, then exchanges one trusted
  publishing credential and pushes in order, idempotently (a version already
  on RubyGems with the same checksum is skipped, a different checksum stops
  the run). A manual dispatch of `release.yml` is always a dry run.
- Never `gem push` by hand. Never move or delete a `v*` tag.

## Standing rules

Versions move in lockstep on the maintainer's explicit go. Never add a
`rescue LoadError` around a sibling require; the umbrella is not a shell,
a missing dependency is a real failure. Changelogs follow Keep a Changelog:
in-progress notes head the next version's undated `## [X]` heading.

Naming: "Poetry" is the product in prose; gem names, constants, and
identifiers stay as they are.
