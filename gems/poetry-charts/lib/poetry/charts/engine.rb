# frozen_string_literal: true

require "rails/engine"

module Poetry
  module Charts
    class Engine < ::Rails::Engine
      # Standard engine layout: app/components is picked up like poetry-ui's.
      config.autoload_paths << "#{Poetry::Charts.root}/app/components"
      config.eager_load_paths << "#{Poetry::Charts.root}/app/components"

      initializer "poetry_charts.helpers" do
        ActiveSupport.on_load(:action_view) do
          include Poetry::Charts::ComponentsHelper
        end
      end

      initializer "poetry_charts.previews" do |app|
        if app.config.respond_to?(:view_component)
          app.config.view_component.previews.paths << "#{Poetry::Charts.root}/app/components"
        end
      end

      # Lookbook is a dev-only dependency; guard so the engine never crashes
      # a production (or lean test) host that does not load it (the
      # poetry-core pattern).
      initializer "poetry_charts.setup_lookbook" do |app|
        app.config.lookbook.preview_paths << "#{Poetry::Charts.root}/app/components" if defined?(Lookbook)
      end

      # Make the client chrome + the motion stylesheet servable by Propshaft.
      initializer "poetry_charts.assets" do |app|
        if app.config.respond_to?(:assets)
          app.config.assets.paths << Poetry::Charts.root.join("app/javascript").to_s
          app.config.assets.paths << Poetry::Charts.root.join("app/assets/stylesheets").to_s
        end
      end

      # The importmap-first JS channel (the poetry-core shape).
      initializer "poetry_charts.importmap", before: "importmap" do |app|
        if app.config.respond_to?(:importmap)
          app.config.importmap.paths << Poetry::Charts.root.join("config/importmap.rb")
          app.config.importmap.cache_sweepers << Poetry::Charts.root.join("app/javascript")
        end
      end
    end
  end
end
