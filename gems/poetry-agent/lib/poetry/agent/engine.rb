# frozen_string_literal: true

require "rails/engine"
require "action_dispatch"

module Poetry
  module Agent
    # The Rails engine: merges the WebMCP controllers manifest into
    # poetry-core's catalog (so `webmcp:` roots validate at render), serves
    # the runtime JavaScript through the importmap-first channel, and
    # mounts the origin-trial middleware. Loading the gem is the only
    # integration step; the host imports `@poetry/agent` beside
    # `@poetry/controllers`.
    class Engine < ::Rails::Engine
      initializer "poetry_agent.controllers_manifest", before: :eager_load! do
        Poetry::Core::Stimulus::Manifest.register(Poetry::Agent::WebMCP.manifest_path.to_s)
      end

      initializer "poetry_agent.origin_trial" do |app|
        app.config.middleware.use Poetry::Agent::WebMCP::OriginTrial
      end

      initializer "poetry_agent.assets" do |app|
        if app.config.respond_to?(:assets)
          app.config.assets.paths << Poetry::Core.javascript_path(Poetry::Agent.root).to_s
        end
      end

      # The importmap-first JS channel (the poetry-core shape); bundler
      # hosts use the @poetry/agent npm package instead.
      initializer "poetry_agent.importmap", before: "importmap" do |app|
        if app.config.respond_to?(:importmap)
          app.config.importmap.paths << Poetry::Agent.root.join("config/importmap.rb")
          app.config.importmap.cache_sweepers << Poetry::Core.javascript_path(Poetry::Agent.root)
        end
      end
    end
  end
end
