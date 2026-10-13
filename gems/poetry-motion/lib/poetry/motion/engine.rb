# frozen_string_literal: true

require "rails/engine"

module Poetry
  module Motion
    # The Rails engine: component autoload paths, the controllers manifest,
    # previews, asset paths and the importmap pins. Loading the gem is the
    # only integration step besides `poetry:install --motion`.
    #
    # @example Install via the host Gemfile
    #   gem "poetry-motion"
    class Engine < ::Rails::Engine
      config.autoload_paths << "#{Poetry::Motion.root}/app/components"
      config.eager_load_paths << "#{Poetry::Motion.root}/app/components"

      # The motion controllers manifest joins core's catalog, so
      # use_stimulus declarations validate poetry--motion--* names like
      # core's own (before components load).
      initializer "poetry_motion.controllers_manifest", before: :eager_load! do
        Poetry::Core::Stimulus::Manifest.register("#{Poetry::Motion.root}/config/controllers_manifest.json")
      end

      # Registered from to_prepare, so a host that loads ActionView early
      # never resolves the helper before the autoload paths exist (the
      # poetry-charts fix).
      initializer "poetry_motion.helpers" do |app|
        app.config.to_prepare do
          ActiveSupport.on_load(:action_view) { include Poetry::Motion::ComponentsHelper }
        end
      end

      initializer "poetry_motion.previews" do |app|
        if app.config.respond_to?(:view_component)
          app.config.view_component.previews.paths << "#{Poetry::Motion.root}/app/components"
        end
      end

      initializer "poetry_motion.setup_lookbook" do |app|
        app.config.lookbook.preview_paths << "#{Poetry::Motion.root}/app/components" if defined?(Lookbook)
      end

      initializer "poetry_motion.assets" do |app|
        if app.config.respond_to?(:assets)
          app.config.assets.paths << Poetry::Motion.root.join("app/javascript").to_s
          app.config.assets.paths << Poetry::Motion.root.join("app/assets/stylesheets").to_s
        end
      end

      initializer "poetry_motion.importmap", before: "importmap" do |app|
        if app.config.respond_to?(:importmap)
          app.config.importmap.paths << Poetry::Motion.root.join("config/importmap.rb")
          app.config.importmap.cache_sweepers << Poetry::Motion.root.join("app/javascript")
        end
      end
    end
  end
end
