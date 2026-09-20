# frozen_string_literal: true

# Start coverage before the code under test loads (see poetry-core).
unless ENV["COVERAGE"] == "0"
  require "simplecov"
  SimpleCov.start do
    enable_coverage :branch
    skip %r{^/test/}
    cover "{app,lib}/**/*.rb"
    # The floor: one point under the measured value, identical on both CI
    # Rubies. Raise it when coverage climbs; never lower it in a feature commit.
    minimum_coverage line: 97, branch: 78
  end
end

ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"
require "rails/test_help"
require "minitest/autorun"
