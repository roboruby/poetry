# frozen_string_literal: true

# Start coverage before any of the code-under-test loads so lib/ and
# app/components are instrumented. Disable with COVERAGE=0 for fast focused runs.
unless ENV["COVERAGE"] == "0"
  require "simplecov"
  SimpleCov.start do
    enable_coverage :branch
    skip %r{^/test/}
    cover "{app,lib}/**/*.rb"
  end
end

# Boot the on-disk dummy host (test/dummy). It defines the engine before the
# app initializes, so the engine's app/components autoloads the standard way.
ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"
require "minitest/autorun"
