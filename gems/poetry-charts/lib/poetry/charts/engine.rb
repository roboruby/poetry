# frozen_string_literal: true

require "rails/engine"

module Poetry
  module Charts
    class Engine < ::Rails::Engine
      # Standard engine layout: app/components is picked up like poetry-ui's.
      config.autoload_paths << "#{Poetry::Charts.root}/app/components"
      config.eager_load_paths << "#{Poetry::Charts.root}/app/components"

      initializer "poetry_charts.previews" do |app|
        if app.config.respond_to?(:view_component)
          app.config.view_component.previews.paths << "#{Poetry::Charts.root}/app/components"
        end
      end
    end
  end
end
