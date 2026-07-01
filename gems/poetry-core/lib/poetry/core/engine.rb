# frozen_string_literal: true

require "rails/engine"
# Rails::Engine::Configuration references ActionDispatch::Routing::RouteSet as
# soon as `config` is touched (below), so action_dispatch must be loaded for the
# engine to be requirable standalone (e.g. via `require "poetry/core"`), not only
# inside an already-booted Rails app.
require "action_dispatch"

module Poetry
  module Core
    class Engine < ::Rails::Engine
      # isolate_namespace Poetry::Core

      config.poetry_core = Poetry::Core::Config.current

      # Add components to autoload paths for Zeitwerk
      config.autoload_paths << "#{Poetry::Core.root}/app/components"
      config.eager_load_paths << "#{Poetry::Core.root}/app/components"

      initializer "poetry_core.tag_helper" do
        ActiveSupport.on_load(:action_view) do
          include Poetry::Core::TagHelper
        end
      end

      initializer "poetry_core.previews" do
        ActiveSupport.on_load(:view_component) do
          ViewComponent::Preview.extend Poetry::Core::Preview::Sidecarable
        end
      end

      initializer "poetry_core.view_component" do |app|
        app.config.view_component.previews.paths << "#{Poetry::Core.root}/app/components"
      end

      # Lookbook is a dev-only dependency; guard so the engine never crashes a
      # production (or lean test) host that does not load it.
      initializer "poetry_core.setup_lookbook" do |app|
        app.config.lookbook.preview_paths << "#{Poetry::Core.root}/app/components" if defined?(Lookbook)
      end

      initializer "poetry_core.assets", before: "propshaft.set_manifest" do |_app|
        # Add JavaScript to asset paths for Propshaft
        if Rails.application.config.respond_to?(:assets)
          Rails.application.config.assets.paths << Poetry::Core.root.join("app/javascript")
        end
      end

      # The importmap-first JS channel: merge poetry's pins into the
      # host's importmap so `import ... from "@poetry/controllers"` works
      # with zero build. Guarded - bundler hosts (esbuild/Vite) use the npm
      # channel instead and never load importmap-rails.
      initializer "poetry_core.importmap", before: "importmap" do |app|
        if app.config.respond_to?(:importmap)
          app.config.importmap.paths << Poetry::Core.root.join("config/importmap.rb")
          app.config.importmap.cache_sweepers << Poetry::Core.root.join("app/javascript")
        end
      end
    end
  end
end
