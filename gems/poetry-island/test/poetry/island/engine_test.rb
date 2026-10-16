# frozen_string_literal: true

require "test_helper"

module Poetry
  module Island
    # The engine inside a host: its version rides with the family, the
    # helper reaches the views, and its importmap pins the whole tree.
    class EngineTest < ActiveSupport::TestCase
      def test_the_version_rides_with_the_family
        assert_equal Poetry::Core::VERSION, Poetry::Island::VERSION
      end

      def test_the_helper_is_in_the_views
        assert_respond_to ApplicationController.helpers, :poetry_island
      end

      def test_the_entry_and_the_controller_preload
        packages = Rails.application.importmap.packages

        assert_equal "poetry/island/index.js", packages.fetch("@poetry/island").path
        assert packages.fetch("@poetry/island").preload
        assert packages.fetch("@poetry/island/island_controller").preload
      end

      def test_every_shipped_file_has_a_pin_and_every_pin_a_file
        javascript = Poetry::Island.root.join("app/javascript")
        imports = JSON.parse(Rails.application.importmap.to_json(resolver: PathResolver.new))["imports"]
        pinned = imports.values.map { |url| url.delete_prefix("/") }
        files = Dir.glob("poetry/island/**/*.js", base: javascript)

        assert_empty files - pinned, "files with no importmap pin"
        Rails.application.importmap.packages.each_value do |package|
          next unless package.path.start_with?("poetry/island")

          assert_path_exists javascript.join(package.path)
        end
      end

      def test_the_controller_is_in_the_manifest_catalog
        definition = Poetry::Core::Stimulus::Manifest.catalog.fetch("poetry--island--island")

        assert_equal %w[input shell], definition["targets"]
        assert_equal %w[import mode], definition["values"].keys.sort
        assert_equal %w[error mount], definition["events"]
      end

      # Resolves an importmap path to a URL the way a host's asset helper would.
      class PathResolver
        def path_to_asset(path) = "/#{path}"
      end
    end
  end
end
