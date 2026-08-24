# frozen_string_literal: true

require "rails/engine"

module Poetry
  module Ui
    # The Rails engine: wires the component classes, the poetry_* view
    # helpers, the Turbo Stream toast action, and the preview paths into
    # the host app.
    class Engine < ::Rails::Engine
      # Standard engine layout: app/components, app/helpers, and
      # config/locales are picked up by Rails' engine path conventions.
      config.autoload_paths << "#{Poetry::Ui.root}/app/components"
      config.eager_load_paths << "#{Poetry::Ui.root}/app/components"

      # ComponentsHelper lives in app/helpers (Zeitwerk-autoloaded), so unlike
      # a lib/ helper it is NOT already loaded at gem-require time. A host gem
      # that forces ActionView to load *during* initialization - e.g. an
      # ActionText editor prepending to ActionView::Helpers::FormHelper
      # - fires this on_load hook before the engine's
      # app/helpers constant is resolvable, raising NameError at boot. Deferring
      # the hook registration into a to_prepare block runs it only once autoload
      # paths are wired (and re-runs safely on reload), so the constant always
      # resolves. (poetry-core's TagHelper avoids this only because it lives in
      # lib/ and is required eagerly.)
      initializer "poetry_ui.helpers" do |app|
        app.config.to_prepare do
          ActiveSupport.on_load(:action_view) do
            include Poetry::Ui::ComponentsHelper
          end
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

      # Lookbook is a dev-only dependency; guard so the engine never crashes
      # a production (or lean test) host that does not load it (the
      # poetry-core pattern).
      initializer "poetry_ui.setup_lookbook" do |app|
        app.config.lookbook.preview_paths << "#{Poetry::Ui.root}/app/components" if defined?(Lookbook)
      end
    end
  end
end
