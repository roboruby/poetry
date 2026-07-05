# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# The engine under development next door (published dependency once released).
gem "poetry-core", path: "../poetry-core"

gem "irb"
gem "rake", "~> 13.0"

gem "minitest", "~> 6.0.6"

gem "rubocop", "~> 1.21"
gem "rubocop-minitest", require: false
gem "rubocop-performance", require: false
gem "rubocop-rake", require: false

gem "bundler-audit", require: false
gem "simplecov", require: false
gem "tailwindcss-ruby" # compiled-CSS verify gate (rake css:verify_compiled), lands with the chart dictionaries

group :test do
  # The real-browser layer (rake test:accessibility / test:visual) - needs
  # Chrome, so neither task joins the default gate.
  gem "axe-core-api" # axe driven via Cuprite (see poetry-ui)
  gem "capybara"
  gem "chunky_png", require: false # visual-baseline tolerance compare
  gem "cuprite"
  gem "puma", require: false # Capybara's rack server for the dummy host
end
