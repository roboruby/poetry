# frozen_string_literal: true

# Start coverage before the code under test loads. Disable with COVERAGE=0
# for fast focused runs.
unless ENV["COVERAGE"] == "0"
  require "simplecov"
  SimpleCov.start do
    enable_coverage :branch
    skip %r{^/test/}
    cover "lib/**/*.rb"
    # The floor: one point under the measured value. Raise it when coverage
    # climbs; never lower it in a feature commit.
    minimum_coverage line: 89, branch: 78
  end
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "poetry/extract"
require "minitest/autorun"
