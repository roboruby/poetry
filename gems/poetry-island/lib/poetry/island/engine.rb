# frozen_string_literal: true

require "rails/engine"

module Poetry
  module Island
    # The Rails engine: component autoload paths, the controllers manifest,
    # previews, asset paths and the importmap pins. Loading the gem is the
    # only integration step besides `poetry:install`, which registers the
    # controller and pins the app's own islands directory.
    #
    # @example Install via the host Gemfile
    #   gem "poetry-island"
    class Engine < ::Rails::Engine
      config.autoload_paths << "#{Poetry::Island.root}/app/components"
      config.eager_load_paths << "#{Poetry::Island.root}/app/components"

      # The island controller's manifest joins core's catalog, so the
      # component's use_stimulus declaration validates like core's own.
      initializer "poetry_island.controllers_manifest", before: :eager_load! do
        Poetry::Core::Stimulus::Manifest.register("#{Poetry::Island.root}/config/controllers_manifest.json")
      end

      # Registered from to_prepare, so a host that loads ActionView early
      # never resolves the helper before the autoload paths exist.
      initializer "poetry_island.helpers" do |app|
        app.config.to_prepare do
          ActiveSupport.on_load(:action_view) { include Poetry::Island::ComponentsHelper }
        end
      end

      initializer "poetry_island.previews" do |app|
        if app.config.respond_to?(:view_component)
          app.config.view_component.previews.paths << "#{Poetry::Island.root}/app/components"
        end
      end

      initializer "poetry_island.setup_lookbook" do |app|
        app.config.lookbook.preview_paths << "#{Poetry::Island.root}/app/components" if defined?(Lookbook)
      end

      initializer "poetry_island.assets" do |app|
        if app.config.respond_to?(:assets)
          app.config.assets.paths << Poetry::Core.javascript_path(Poetry::Island.root).to_s
        end
      end

      initializer "poetry_island.importmap", before: "importmap" do |app|
        if app.config.respond_to?(:importmap)
          app.config.importmap.paths << Poetry::Island.root.join("config/importmap.rb")
          app.config.importmap.cache_sweepers << Poetry::Core.javascript_path(Poetry::Island.root)
        end
      end
    end
  end
end
