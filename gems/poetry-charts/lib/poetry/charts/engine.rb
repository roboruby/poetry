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

      # Make the client chrome servable by Propshaft.
      initializer "poetry_charts.assets" do |app|
        app.config.assets.paths << Poetry::Charts.root.join("app/javascript").to_s if app.config.respond_to?(:assets)
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
