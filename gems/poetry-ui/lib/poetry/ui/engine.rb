# frozen_string_literal: true

require "rails/engine"

module Poetry
  module Ui
    class Engine < ::Rails::Engine
      # Standard engine layout: app/components, app/helpers, and
      # config/locales are picked up by Rails' engine path conventions.
      config.autoload_paths << "#{Poetry::Ui.root}/app/components"
      config.eager_load_paths << "#{Poetry::Ui.root}/app/components"

      initializer "poetry_ui.helpers" do
        ActiveSupport.on_load(:action_view) do
          include Poetry::Ui::ComponentsHelper
        end
      end

      initializer "poetry_ui.previews" do |app|
        app.config.view_component.previews.paths << "#{Poetry::Ui.root}/app/components"
      end
    end
  end
end
