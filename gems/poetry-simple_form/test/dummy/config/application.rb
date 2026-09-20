# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_model/railtie"
require "action_controller/railtie"
require "action_view/railtie"

require "view_component"
require "poetry/core"
require "poetry/ui"
require "poetry/lucide"
require "poetry/simple_form"

module Dummy
  # Minimal Rails host for the shim: no database (ActiveModel test
  # models), no assets - forms are pure render.
  class Application < Rails::Application
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.logger = Logger.new(nil)
    config.active_support.test_order = :random
    config.hosts.clear
  end
end
