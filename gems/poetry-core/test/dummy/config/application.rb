# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_model/railtie"
require "action_controller/railtie"
require "action_view/railtie"

require "view_component"
require "poetry/core"

module Dummy
  # Minimal Rails host for exercising the engine + components in tests and
  # previews. Intentionally lean: no database, no asset pipeline yet — Propshaft
  # / importmap get wired when there is real JS/CSS to serve (later milestone).
  class Application < Rails::Application
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.logger = Logger.new(nil) # Suppress logs in tests
    config.active_support.test_order = :random
  end
end
