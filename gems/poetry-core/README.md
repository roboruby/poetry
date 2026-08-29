# poetry-core

The Rails engine, component DSL, and primitives that power **[poetry](https://github.com/roboruby/poetry)** — the AI-native, Rails-first component library. This gem is the *framework* layer (the engine, the `Component` base class plus the Styles/Options DSL, the Stimulus integration, the preview infrastructure). The components themselves live in `poetry-ui`.

> **Status: early release.** The API is settling but not frozen; the CHANGELOG lists every breaking change.

## Installation

Most users should depend on the umbrella **`poetry`** gem rather than `poetry-core` directly.

```bash
bundle add poetry-core
```

## Development

After checking out the repo, run `bin/setup` to install dependencies, then `bundle exec rake` to run the tests and RuboCop. `bin/console` gives an interactive prompt.

## Release

Releases publish to [RubyGems.org](https://rubygems.org) via GitHub Actions OIDC **trusted publishing** (no API keys). Bump `Poetry::Core::VERSION` in `lib/poetry/core/version.rb`, commit, then push a `vX.Y.Z` tag — the `Release` workflow builds and publishes the gem.

## Lineage

poetry-core evolves the framework layer of `view_component_plus` (the `Plus` gem) — itself a synthesis of view_component-contrib and fox_tail.

## License

Available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
See `THIRD_PARTY_NOTICES.md` for adapted code.
