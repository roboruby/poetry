# frozen_string_literal: true

require "rails/generators"

module Poetry
  module SimpleForm
    module Generators
      # `rails g poetry:simple_form:install` - one initializer, the whole
      # shim: activate! re-maps the input types and installs the
      # passthrough wrapper. Delete the file to fall back to stock
      # simple_form rendering.
      class InstallGenerator < Rails::Generators::Base
        source_root File.expand_path("templates", __dir__)

        def create_initializer
          create_file "config/initializers/poetry_simple_form.rb", <<~RUBY_FILE
            # poetry renders simple_form's inputs (the migration bridge):
            # f.input keeps working while views move to
            # form_with(builder: Poetry::Ui::FormBuilder). Remove this file
            # to restore stock simple_form rendering.
            Poetry::SimpleForm.activate!
          RUBY_FILE
        end
      end
    end
  end
end
