# poetry

An AI-native, Rails-first component library — a shadcn/ui-parity design system built on ViewComponent, Hotwire, and Tailwind, designed so coding agents compose UI inside a constrained design system.

> **Status: early release.** This `0.0.1` reserves the gem name on RubyGems while the library is in active planning. There is no public API yet.

## Installation

```bash
bundle add poetry
```

## Development

After checking out the repo, run `bin/setup` to install dependencies, then `bundle exec rake` to run the tests and RuboCop. `bin/console` gives an interactive prompt.

## Release

Releases publish to [RubyGems.org](https://rubygems.org) via GitHub Actions OIDC **trusted publishing** (no API keys). To cut a release: bump `Poetry::VERSION` in `lib/poetry/version.rb`, commit, then push a `vX.Y.Z` tag — the `Release` workflow builds and publishes the gem.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/roboruby/poetry.

## License

Available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
