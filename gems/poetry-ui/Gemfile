# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# The engine under development next door (published dependency once released).
# CodeBlock's soft highlighting dependency - the dummy/gate builds exercise
# the rouge path (hosts without rouge get the plain fallback).
gem "rouge"

gem "poetry-core", path: "../poetry-core"
gem "poetry-lucide", path: "../poetry-lucide"

gem "irb"
gem "rake", "~> 13.0"

gem "minitest", "~> 6.0.6"

gem "rubocop", "~> 1.21"
gem "rubocop-minitest", require: false
gem "rubocop-performance", require: false
gem "rubocop-rake", require: false

gem "bundler-audit", require: false
gem "herb" # template-class scan in poetry:install (build-time, optional in hosts)
gem "lookbook", "~> 2.3" # the preview browser over the sidecar preview corpus - dev-only, never a runtime dep
gem "nokogiri"
gem "simplecov", require: false
gem "tailwindcss-ruby" # compiled-CSS verify gate (rake css:verify_compiled)

group :test do
  # The real-browser layer (rake test:accessibility / test:visual) - needs
  # Chrome, so neither task joins the default gate.
  gem "axe-core-api" # axe-core-capybara hard-requires selenium-webdriver; we drive axe via Cuprite
  gem "capybara"
  gem "chunky_png", require: false # visual-baseline tolerance compare
  gem "cuprite"
  gem "puma", require: false # Capybara's rack server for the dummy host

  # The middle tier (rake test:dommy): real Stimulus controllers +
  # computed styles headlessly in Minitest, no browser. Pre-1.0 - pinned to
  # exact SHAs (both repos hit 0.9.0 on 2026-06-22; expect API movement).
  gem "dommy", git: "https://github.com/takahashim/dommy",
               ref: "04bd303fb6fdb7c3ae20b569dd39541a9d7e73b0",
               glob: "gems/dommy/*.gemspec" # monorepo: dommy + dommy-rack + dommy-rails + capybara-dommy
  gem "dommy-js-quickjs", git: "https://github.com/takahashim/dommy-js-quickjs",
                          ref: "2b98eb6c5adc491f89425c2a08cc00a7462c90cb"

  # The pagination-adapter integration tests (poetry:pagination) - the
  # generated adapters are host-app code, never runtime deps.
  gem "kaminari"
  gem "pagy", "~> 43.0"
  gem "will_paginate"
end
