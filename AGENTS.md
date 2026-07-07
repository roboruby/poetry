# AGENTS.md — poetry

The meta-gem: the umbrella that versions and depends on the poetry family
(poetry-core, poetry-ui, poetry-lucide; poetry-charts and poetry-reactive are
opt-in additions). Almost all real work happens in the sibling gems — check
their own AGENTS.md files.

## Gates

- `bundle exec rake test`
- `bundle exec rubocop`

## Standing rules

- The naming hold: never push, publish, or claim gems — the whole family may
  still be renamed.
- Version/dependency changes here must track the siblings; don't bump one
  side alone.
