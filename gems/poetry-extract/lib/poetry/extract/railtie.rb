# frozen_string_literal: true

require "rails/railtie"

module Poetry
  module Extract
    # Installs the poetry:design:extract task into any Rails host the
    # moment the gem is bundled.
    class Railtie < Rails::Railtie
      rake_tasks do
        load File.expand_path("../../tasks/poetry/extract.rake", __dir__)
      end
    end
  end
end
