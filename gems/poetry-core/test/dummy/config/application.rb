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
  # / importmap get wired when there is real JS/CSS to serve.
  class Application < Rails::Application
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    # A suite never reloads its classes. Left on (Rails' default where no environment file says
    # otherwise), reloading swaps every class out as soon as a watched file changes while the tests
    # run, and a test class written inside a component's namespace can no longer find its component.
    config.enable_reloading = false if Rails.env.test?
    config.logger = Logger.new(nil) # Suppress logs in tests
    config.active_support.test_order = :random

    # A framework loaded before initialization completes is a boot fault in
    # this host, not a line in a log: the Rails main leg has the setting.
    config.action_on_early_load_hook = :raise if config.respond_to?(:action_on_early_load_hook)
  end
end
