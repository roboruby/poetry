# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# The sibling gems ride local paths while the family is checked out side by
# side (development); anywhere else (CI, a release job, a lone clone) they
# resolve from RubyGems through the gemspec's exact pins.
sibling = lambda do |name|
  path = File.expand_path("../#{name}", __dir__)
  File.directory?(path) ? { path: path } : {}
end

gem "poetry-core", **sibling.call("poetry-core")

gem "irb"
gem "minitest", "~> 6.0.6"
gem "nokogiri" # the fetch script's SVG parser (dev-only)
gem "rake", "~> 13.0"
gem "rubocop", "~> 1.21"
gem "rubocop-minitest", require: false
gem "rubocop-performance", require: false
gem "rubocop-rake", require: false
gem "yard", require: false
