# frozen_string_literal: true

require "rails/generators"

module Poetry
  # `rails g poetry:scaffold_templates`:
  # Rails has always let an app override its generator templates
  # from lib/templates/; what was missing was a set that renders with
  # poetry. This copies scaffold view templates - and a matching scaffold
  # controller template - so the STANDARD `rails g scaffold` produces
  # poetry-composed output: a DataTable index with sanitized URL state
  # (sortable whitelist, filter, pagination), Field-composed forms with
  # attribute-type -> component mapping (plus column-name -> input-type
  # heuristics and `null: false` -> required), a MetadataList show, and a
  # destructive-variant delete. The copies are the app's to edit; re-runs
  # never overwrite (skip-if-exists, the poetry:add contract).
  class ScaffoldTemplatesGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    VIEW_TEMPLATES = %w[index show new edit _form partial].freeze

    SKIP_CONTROLLER_DESC = "Skip the scaffold_controller override (index keeps the stock " \
                           "all-records query; the generated index view expects @state/@pages " \
                           "from the poetry controller template)"

    class_option :skip_controller, type: :boolean, default: false, desc: SKIP_CONTROLLER_DESC

    def copy_view_templates
      VIEW_TEMPLATES.each do |name|
        copy_file "#{name}.html.erb.tt", "lib/templates/erb/scaffold/#{name}.html.erb.tt", skip: true
      end
    end

    def copy_controller_template
      return if options[:skip_controller]

      copy_file "controller.rb.tt", "lib/templates/rails/scaffold_controller/controller.rb.tt", skip: true
    end

    def show_next_steps
      say ""
      say "poetry scaffold templates installed.", :green
      say "  bin/rails generate scaffold Post title:string body:text"
      say "now produces poetry-composed views#{" and a URL-state index controller" unless options[:skip_controller]}."
      say "The templates under lib/templates/ are yours to edit."
      say ""
    end
  end
end
