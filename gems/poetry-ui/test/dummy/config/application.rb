# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_model/railtie"
require "action_controller/railtie"
require "action_view/railtie"

require "view_component"
require "poetry/core"
require "poetry/ui"

module Dummy
  # Minimal Rails host for exercising poetry-ui's components in tests.
  class Application < Rails::Application
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.logger = Logger.new(nil) # Suppress logs in tests
    config.active_support.test_order = :random
  end
end
