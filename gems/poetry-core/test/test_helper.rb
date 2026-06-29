# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# Set up a minimal Rails environment for testing the engine + framework.
ENV["RAILS_ENV"] = "test"

require "rails"
require "active_model/railtie"
require "action_controller/railtie"
require "action_view/railtie"

# A minimal host application so the engine can be defined and booted.
module TestApp
  class Application < Rails::Application
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.logger = Logger.new(nil) # Suppress logs in tests
    config.active_support.test_order = :random
  end
end

TestApp::Application.initialize!

require "poetry/core"
require "minitest/autorun"
