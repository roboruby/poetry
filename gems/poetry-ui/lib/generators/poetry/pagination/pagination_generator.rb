# frozen_string_literal: true

require "rails/generators"

module Poetry
  module Generators
    # `rails g poetry:pagination [kaminari|pagy|will_paginate]` - copies a
    # poetry adapter for the host's paginator(s) as OWNED host-app code
    # (the copied-source doctrine; poetry:diff tracks drift). No argument:
    # every paginator loaded in this app gets its adapter.
    #
    # The doctrine baked into every adapter: poetry owns the window
    # (siblings/edges compute the visible pages) - the paginator's own
    # window options deliberately do not apply, so pagination looks the
    # same whichever gem drives it.
    class PaginationGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      ADAPTERS = {
        "kaminari" => { detect: -> { defined?(::Kaminari) },
                        template: "kaminari_paginator.html.erb",
                        destination: "app/views/kaminari/_paginator.html.erb" },
        "pagy" => { detect: -> { defined?(::Pagy) },
                    template: "poetry_pagy_helper.rb",
                    destination: "app/helpers/poetry_pagy_helper.rb" },
        "will_paginate" => { detect: -> { defined?(::WillPaginate) },
                             template: "poetry_link_renderer.rb",
                             destination: "app/lib/poetry_link_renderer.rb" }
      }.freeze

      argument :paginator, type: :string, required: false,
                           banner: "kaminari|pagy|will_paginate",
                           desc: "the paginator to adapt (omit to detect every installed one)"

      def install_adapters
        names = requested_adapters
        if names.empty?
          say_status :skip, "no paginator detected (kaminari / pagy / will_paginate) - " \
                            "add one to the Gemfile first, or name it explicitly", :yellow
          return
        end

        names.each do |name|
          spec = ADAPTERS.fetch(name)
          copy_file spec[:template], spec[:destination]
        end
      end

      private

      def requested_adapters
        if paginator.present?
          unless ADAPTERS.key?(paginator)
            raise Thor::Error, "unknown paginator #{paginator.inspect} - " \
                               "one of: #{ADAPTERS.keys.join(", ")}"
          end
          unless ADAPTERS.fetch(paginator)[:detect].call
            raise Thor::Error, "#{paginator} is not loaded in this app - add the gem, bundle, and re-run"
          end

          [paginator]
        else
          ADAPTERS.select { |_name, spec| spec[:detect].call }.keys
        end
      end
    end
  end
end
