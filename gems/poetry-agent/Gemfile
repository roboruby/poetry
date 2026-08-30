# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# The family under development next door (published dependencies once
# released). poetry-ui and poetry-lucide are SOFT runtime requires of the
# exe (skills, helpers, icon names ride along when bundled) and hard test
# dependencies: the exe parity test drives the real subprocess with them.
# The sibling gems ride local paths while the family is checked out side by
# side (development); anywhere else (CI, a release job, a lone clone) they
# resolve from RubyGems through the gemspec's exact pins.
sibling = lambda do |name|
  path = File.expand_path("../#{name}", __dir__)
  File.directory?(path) ? { path: path } : {}
end

gem "poetry-core", **sibling.call("poetry-core")
gem "poetry-lucide", **sibling.call("poetry-lucide")
gem "poetry-ui", **sibling.call("poetry-ui")

gem "irb"
gem "rake", "~> 13.0"

gem "minitest", "~> 6.0.6"

gem "rubocop", "~> 1.21"
gem "rubocop-minitest", require: false
gem "rubocop-performance", require: false
gem "rubocop-rake", require: false

gem "bundler-audit", require: false
gem "herb" # the ERB parser behind check (build-time, optional in hosts)
gem "rack-test", require: false
gem "simplecov", require: false
gem "yard", require: false
