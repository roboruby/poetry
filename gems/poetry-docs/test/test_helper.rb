# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "dummy/config/environment"
require "rails/test_help"
require "minitest/autorun"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
  end
end

# The engine is mounted at the dummy's root, so its route helpers answer
# the paths the tests request (root_path, component_path, library_path).
module ActionDispatch
  class IntegrationTest
    include Poetry::Docs::Engine.routes.url_helpers
  end
end
