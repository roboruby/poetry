# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_model/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"
require "propshaft"
require "importmap-rails"
require "turbo-rails"
require "stimulus-rails"
require "kaminari"
require "pagy"
require "will_paginate"
require "poetry/docs"

# The dummy host: the engine at the root of a bare Rails app, for the tests
# and for docs authoring (bin/dev). No database, no jobs, no mail; the
# docs need none, and a real host brings its own.
module Dummy
  class Application < Rails::Application
    config.root = File.expand_path("..", __dir__)
    config.load_defaults(ENV["POETRY_RAILS"] == "main" ? 8.2 : 8.1)
    config.eager_load = ENV["CI"].present?
    config.action_on_early_load_hook = :raise if config.respond_to?(:action_on_early_load_hook)
    config.action_view.erb_implementation = :herb if ENV["POETRY_RAILS"] == "main"
    config.active_support.test_order = :random
    config.action_controller.raise_on_missing_callback_actions = true
    config.cache_store = :memory_store
    config.public_file_server.enabled = true
    config.hosts.clear

    if Rails.env.test?
      config.enable_reloading = false
      config.consider_all_requests_local = true
      config.action_dispatch.show_exceptions = :rescuable
      config.action_controller.allow_forgery_protection = false
      config.active_support.deprecation = :stderr
      config.logger = Logger.new(nil)
    end

    if Rails.env.development?
      config.consider_all_requests_local = true
      config.action_controller.enable_fragment_cache_logging = true
      config.action_view.annotate_rendered_view_with_filenames = true
      config.logger = ActiveSupport::Logger.new($stdout)
    end

    # The production shape poetryui.com ran on before the engine moved
    # into its host: kept so the deploy repository can build this app from
    # the tree until the hostname moves.
    if Rails.env.production?
      config.eager_load = true
      config.consider_all_requests_local = false
      config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }
      config.assume_ssl = true
      config.force_ssl = true
      config.log_tags = [ :request_id ]
      config.logger = ActiveSupport::TaggedLogging.logger($stdout)
      config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
      config.cache_store = :memory_store, { size: 256.megabytes }
      config.action_dispatch.show_exceptions = :rescuable
    end
  end
end
