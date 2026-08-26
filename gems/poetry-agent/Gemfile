# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# The family under development next door (published dependencies once
# released). poetry-ui and poetry-lucide are SOFT runtime requires of the
# exe (skills, helpers, icon names ride along when bundled) and hard test
# dependencies: the exe parity test drives the real subprocess with them.
gem "poetry-core", path: "../poetry-core"
gem "poetry-lucide", path: "../poetry-lucide"
gem "poetry-ui", path: "../poetry-ui"

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
