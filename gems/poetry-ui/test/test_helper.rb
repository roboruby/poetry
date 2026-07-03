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
require "minitest/autorun"

module PoetryTestHelpers
  # Swaps Rails.logger for the block and returns the captured warn
  # messages - the lint-warning surface (Popover's nameless dialog,
  # HoverCard's missing href) asserts through this.
  def capture_rails_warnings
    sink = []
    logger = Object.new
    logger.define_singleton_method(:warn) { |message = nil| sink << message }
    previous = Rails.logger
    Rails.logger = logger
    yield
    sink
  ensure
    Rails.logger = previous
  end
end

Minitest::Test.include PoetryTestHelpers
