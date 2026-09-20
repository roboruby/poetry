# AGENTS.md — poetry-extract

The optional design-extraction gem: domain in, theme out.
`bin/rails "poetry:design:extract[stripe.com]"` fetches a site's design
signals (context.dev: styleguide, brand, screenshot, homepage markdown),
composes a DESIGN.md in one Claude call, derives Tailwind v4 `@theme` +
CSS `:root` tokens deterministically, and prints the handoff to
`poetry:design:import` — the AA gate stays the single door into a theme;
this gem never writes one.

## Gates

- `bundle exec rake` — the default chain: `test`, `rubocop`, `yard:verify`,
  `yard:coverage` (every public object documented; floors at 0).

## The parity doctrine

`lib/poetry/extract/derive_tokens.rb` is a function-for-function port of
agentcn's `derive-tokens.ts` (MIT, THIRD_PARTY_NOTICES.md). The upstream
file is the ORACLE: `test/fixtures/oracle/` holds it plus committed
`expected.json`, and the parity suite requires byte-equal output. Never
"fix" behavior in the port alone — change the oracle inputs, regenerate
(`npx -y esbuild derive-tokens.ts --format=esm --outfile=derive-tokens.mjs
&& node run.mjs`, node needed only for that), and keep both sides green.
JS semantics are mirrored deliberately (`js_float` for parseFloat,
`js_to_fixed` for toFixed's half-away-from-zero ties — sprintf rounds
half-to-even and WILL diverge).

## Conventions

- Keys ride env: `CONTEXT_DEV_API_KEY` (fetch; absent = the degraded
  homepage-only path, which must stay working), `ANTHROPIC_API_KEY`
  (compose), `POETRY_EXTRACT_MODEL` (optional override).
- Tests never touch the network: inject fake clients/composers/http.
- Artifacts land under `tmp/poetry/design_extract/<domain>/`; the task
  prints the import invocation and never edits app CSS.

## Standing rules

Releases: versions move in lockstep across the family, with internal
dependencies pinned exactly (`= VERSION`); bumps happen only on the
maintainer's explicit go. Publishing runs only through the tag-triggered
release workflow (OIDC trusted publishing) — never `gem push` by hand. The
CHANGELOG stays bare until 0.1.0; commit messages carry the record.
poetry-core rides a local path in the Gemfile only when checked out beside
this repo; the lockfile is not committed.

Naming: "Poetry" is the product in prose; gem names, constants, and
identifiers stay as they are.

Third-party code: adapt only from MIT-compatible sources (MIT/ISC/BSD;
Apache-2.0 carries its notice). Copyleft (GPL/LGPL/AGPL), restricted-use,
and commercial sources are patterns-and-ideas only — never code. Every
adaptation: the class-doc pointer ("Adapted from an MIT-licensed source
- source and license in THIRD_PARTY_NOTICES.md") + a
THIRD_PARTY_NOTICES.md section — the source URL lives there, never in
code. An adaptation change that doesn't touch THIRD_PARTY_NOTICES.md
is incomplete.
