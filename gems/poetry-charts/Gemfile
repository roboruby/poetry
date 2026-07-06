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

  # The middle tier (rake test:dommy): the real chart controllers -
  # kernel renderer included - headlessly in Minitest, no browser. Same
  # pinned SHAs as poetry-ui (both repos hit 0.9.0 on 2026-06-22; expect
  # API movement pre-1.0).
  gem "dommy", git: "https://github.com/takahashim/dommy",
               ref: "04bd303fb6fdb7c3ae20b569dd39541a9d7e73b0",
               glob: "gems/dommy/*.gemspec" # monorepo: dommy + dommy-rack + dommy-rails + capybara-dommy
  gem "dommy-js-quickjs", git: "https://github.com/takahashim/dommy-js-quickjs",
                          ref: "2b98eb6c5adc491f89425c2a08cc00a7462c90cb"
end
