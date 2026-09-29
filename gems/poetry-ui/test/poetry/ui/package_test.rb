# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The packaged gem carries what a host loads and nothing of the tooling
    # around it. The gemspec lists what stays behind, so a development
    # directory added beside it ships until the gemspec is told.
    class PackageTest < Minitest::Test
      DEVELOPMENT = %w[bin/ gemfiles/ rakelib/ script/ test/].freeze

      def test_no_development_directory_ships
        files = Gem::Specification.load(Poetry::Ui.root.join("poetry-ui.gemspec").to_s).files
        shipped = files.select { |file| file.start_with?(*DEVELOPMENT) }

        assert_empty shipped
        assert_operator files.size, :>, 100, "the file list itself, not an empty one"
      end
    end
  end
end
