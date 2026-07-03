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

      # turbo_stream.poetry_toast(...) - the canonical server-side toast.
      # poetry-ui does not depend on turbo-rails; hosts that load it get
      # the action through turbo's own load hook (a no-op otherwise).
      initializer "poetry_ui.turbo_stream_actions" do
        ActiveSupport.on_load(:turbo_streams_tag_builder) do
          include Poetry::Ui::ToastStreamActions
        end
      end

      initializer "poetry_ui.previews" do |app|
        app.config.view_component.previews.paths << "#{Poetry::Ui.root}/app/components"
      end
    end
  end
end
