# frozen_string_literal: true

# Boot the on-disk dummy host (test/dummy). It defines the engine before the
# app initializes, so the engine's app/components autoloads the standard way.
ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"
require "minitest/autorun"
