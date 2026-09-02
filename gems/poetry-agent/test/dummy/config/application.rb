# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_model/railtie"
require "action_controller/railtie"
require "action_view/railtie"

# The engine is explicit: test_helper loads the gems before Rails, so the
# conditional engine require inside view_component has already passed.
require "view_component"
require "view_component/engine"
require "poetry/core"
require "poetry/ui"
require "poetry/lucide"
require "poetry/agent"

module Dummy
  # The minimal Rails host the renderer tests render through: the
  # component gems, no assets, no previews. Only the tests that need a
  # view context boot it (the rest of the suite stays boot-free).
  class Application < Rails::Application
    config.load_defaults 8.1
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.logger = Logger.new(nil)
    config.active_support.test_order = :random
    config.secret_key_base = "poetry-agent-dummy"
  end
end
