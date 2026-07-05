# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_model/railtie"
require "action_controller/railtie"
require "action_view/railtie"

require "view_component"
require "poetry/core"
require "poetry/charts"

module Dummy
  # Minimal Rails host for exercising poetry-charts in tests: no database
  # (charts are pure render), ViewComponent previews for the browser rig.
  class Application < Rails::Application
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.logger = Logger.new(nil) # Suppress logs in tests
    config.active_support.test_order = :random

    # Serve the static assets the browser rig generates into public/.
    config.public_file_server.enabled = true
  end
end
