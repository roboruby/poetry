# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_model/railtie"
require "action_controller/railtie"
require "action_view/railtie"

require "view_component"
require "importmap-rails"
require "poetry/core"
require "poetry/motion"

module Dummy
  # The test host: the engine boots inside it, with importmap-rails so the
  # pins resolve as a host's would, and the effects' previews mounted.
  class Application < Rails::Application
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.logger = Logger.new(nil)
    config.active_support.test_order = :random

    config.view_component.previews.enabled = true
    config.view_component.previews.route = "/previews"
  end
end
