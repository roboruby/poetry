# frozen_string_literal: true

# Start coverage before the code under test loads (see poetry-core).
unless ENV["COVERAGE"] == "0"
  require "simplecov"
  SimpleCov.start do
    enable_coverage :branch
    add_filter %r{^/test/}
    track_files "{app,lib}/**/*.rb"
  end
end

ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"
require "rails/test_help"
require "minitest/autorun"
