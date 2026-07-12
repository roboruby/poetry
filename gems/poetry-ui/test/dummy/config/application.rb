# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_model/railtie"
require "action_controller/railtie"
require "action_view/railtie"

require "view_component"
require "lookbook" # the preview browser (mounted at /lookbook; engines feed it their preview paths)
require "poetry/core"
require "poetry/ui"
require "poetry/lucide"

module Dummy
  # Minimal Rails host for exercising poetry-ui's components in tests.
  class Application < Rails::Application
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.logger = Logger.new(nil) # Suppress logs in tests
    config.active_support.test_order = :random

    # The real-browser preview rig (rake test:accessibility / test:visual):
    # every preview example is a page at /previews/<preview_name>/<example>,
    # rendered by PreviewsController inside the component_preview layout
    # (compiled Tailwind + poetry's Stimulus controllers via importmap).
    config.view_component.previews.enabled = true
    config.view_component.previews.route = "/previews"
    config.view_component.previews.controller = "PreviewsController"
    config.view_component.previews.default_layout = "component_preview"

    # Serve the generated static assets (rake browser:assets) from public/.
    config.public_file_server.enabled = true

    # The Lookbook browser over the same preview corpus (mounted at
    # /lookbook in routes.rb) - the engines feed it their preview paths.
    config.lookbook.project_name = "poetry" if defined?(Lookbook)
  end
end
