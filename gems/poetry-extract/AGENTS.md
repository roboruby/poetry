# AGENTS.md — poetry-extract

The optional design-extraction gem: domain in, theme out.
`bin/rails "poetry:design:extract[stripe.com]"` fetches a site's design
signals (context.dev: styleguide, brand, screenshot, homepage markdown),
composes a DESIGN.md in one Claude call, derives Tailwind v4 `@theme` +
CSS `:root` tokens deterministically, and prints the handoff to
`poetry:design:import` — the AA gate stays the single door into a theme;
this gem never writes one.

## Gates

- `bundle exec rake` — test + rubocop

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

The naming hold: never push, publish, or claim gems.

Third-party code: adapt only from MIT-compatible sources (MIT/ISC/BSD;
Apache-2.0 carries its notice). Copyleft (GPL/LGPL/AGPL), restricted-use,
and commercial sources are patterns-and-ideas only — never code. Every
adaptation: source URL in the file header + a THIRD_PARTY_NOTICES.md
section. An adaptation change that doesn't touch THIRD_PARTY_NOTICES.md
is incomplete.
