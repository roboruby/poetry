# frozen_string_literal: true

require "rails/engine"

module Poetry
  module Docs
    # The docs engine: its own controllers, layouts, stylesheet and
    # JavaScript graph. A host mounts it at the root of its docs hostname;
    # the dummy host under test/ mounts it at the root outright.
    class Engine < ::Rails::Engine
      isolate_namespace Poetry::Docs

      # The docs' own Stimulus controllers, so poetry:check validates the
      # data-action wiring in the docs' templates like a host's.
      initializer "poetry_docs.controllers_manifest", before: :eager_load! do
        Poetry::Core::Stimulus::Manifest.register(root.join("config/controllers_manifest.json").to_s)
      end

      initializer "poetry_docs.assets" do |app|
        app.config.assets.paths << root.join("app/javascript").to_s if app.config.respond_to?(:assets)
      end

      # The engine's pins join the host's importmap; the layouts name
      # poetry_docs/application as their entry point, so the host's own
      # JavaScript never loads on a docs page.
      initializer "poetry_docs.importmap", before: "importmap" do |app|
        if app.config.respond_to?(:importmap)
          app.config.importmap.paths << root.join("config/importmap.rb")
          app.config.importmap.cache_sweepers << root.join("app/javascript")
        end
      end
    end
  end
end
