# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in poetry.gemspec
gemspec

# poetry-core is developed as a sibling repo. Until it is published to RubyGems,
# depend on it by local path for development; it becomes a gemspec dependency
# once released.
gem "poetry-core", path: "../poetry-core"
gem "poetry-ui", path: "../poetry-ui"
gem "poetry-lucide", path: "../poetry-lucide"

gem "irb"
gem "rake", "~> 13.0"

gem "minitest", "~> 6.0.6"

gem "rubocop", "~> 1.21"
gem "rubocop-minitest", require: false
gem "rubocop-performance", require: false
gem "rubocop-rake", require: false
gem "yard", require: false
