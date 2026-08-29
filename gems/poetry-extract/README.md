# poetry-extract

Domain in, theme out. The optional design-extraction gem for
[poetry](../poetry-ui): point it at a public website and get back a
DESIGN.md document plus deterministic design tokens, ready for poetry's
AA-gated theme importer.

```bash
bin/rails "poetry:design:extract[stripe.com]"
# wrote tmp/poetry/design_extract/stripe.com/{DESIGN.md, theme.tailwind.css, tokens.css}
# next: bin/rails "poetry:design:import[tmp/poetry/design_extract/stripe.com/DESIGN.md]"
```

## Install

```ruby
# Gemfile
gem "poetry-extract"
```

The fetch step calls [context.dev](https://context.dev) (`CONTEXT_DEV_API_KEY`) and the compose step calls Anthropic (`ANTHROPIC_API_KEY`); set both in the environment before running the task.

## How it works

1. **Fetch** — the site's styleguide, brand colors, a screenshot, and the
   homepage as markdown, via [context.dev](https://context.dev)
   (`CONTEXT_DEV_API_KEY`). Without a key it degrades to a plain homepage
   fetch: less evidence, same pipeline.
2. **Compose** — one Claude call (`ANTHROPIC_API_KEY`) writes the
   DESIGN.md prose, screenshot as vision input. Prose only: no token that
   restyles anything comes from the model.
3. **Derive** — the token stylesheets (Tailwind v4 `@theme` + CSS `:root`)
   are computed deterministically from the fetched styleguide/brand: same
   inputs, same bytes, every run. This is a parity-gated port of agentcn's
   `derive-tokens` (MIT — see THIRD_PARTY_NOTICES.md).
4. **Handoff** — nothing touches your theme. The printed
   `poetry:design:import` invocation runs poetry's existing importer,
   which drops any swatch failing WCAG AA.

## License

Available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
Portions adapted from agentcn (MIT) — see `THIRD_PARTY_NOTICES.md`.
