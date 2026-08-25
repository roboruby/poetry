# AGENTS.md — poetry-lucide

The default poetry icon set: Lucide's SVGs vendored at a pinned
upstream commit, sanitized at vendor time, registered with poetry-core's
icon registry. 1,745 icons under `icons/`.

## Gates

- `bundle exec rake test`
- `bundle exec rubocop`

## Conventions

- Icons are updated ONLY via `script/fetch_icons.rb` (re-vendors at a new
  pinned commit and re-sanitizes) — never hand-edit files under `icons/`.
- The vendored SVGs stay under Lucide's ISC license: `LICENSE-LUCIDE.txt`
  ships in the gem and must survive any re-vendor; the gem's own code is
  MIT (`LICENSE.txt`).

## Standing rules

The naming hold: never push, publish, or claim gems.

Third-party code: this gem exists to vendor one MIT-compatible upstream.
Vendor only from MIT-compatible sources (MIT/ISC/BSD; Apache-2.0 carries
its notice) and keep the upstream license text shipping next to the
assets.
