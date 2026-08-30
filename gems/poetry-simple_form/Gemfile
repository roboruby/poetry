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
gem "poetry-lucide", **sibling.call("poetry-lucide")
gem "poetry-ui", **sibling.call("poetry-ui")

gem "irb"
gem "minitest"
gem "puma"
gem "rails", "~> 8.1"
gem "rake", "~> 13.0"
gem "yard", require: false
