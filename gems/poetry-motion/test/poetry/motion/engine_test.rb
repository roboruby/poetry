# frozen_string_literal: true

require "test_helper"

module Poetry
  module Motion
    # The engine inside a host: its version rides with the family, its
    # behaviors resolve by name, and its importmap pins the engine apart
    # from everything that preloads.
    class EngineTest < ActiveSupport::TestCase
      def test_the_version_rides_with_the_family
        assert_equal Poetry::Core::VERSION, Poetry::Motion::VERSION
      end

      def test_motion_behaviors_resolve_by_name
        assert_includes Poetry::Core::Behavior.namespaces, "Poetry::Motion::Behaviors"
      end

      def test_the_engine_pin_does_not_preload
        packages = Rails.application.importmap.packages

        assert_equal "poetry/motion-kernel/engine.js", packages.fetch("@poetry/motion/engine").path
        refute packages.fetch("@poetry/motion/engine").preload
        assert packages.fetch("@poetry/motion").preload
      end

      def test_only_the_entry_the_policy_and_the_loader_preload
        pinned = Rails.application.importmap.preloaded_module_paths(resolver: PathResolver.new, cache_key: :motion)
                      .select { |pin| pin.include?("/poetry/motion") }

        assert_equal %w[/poetry/motion/index.js /poetry/motion/load_engine.js /poetry/motion/policy.js], pinned.sort
      end

      def test_every_shipped_file_has_a_pin
        javascript = Poetry::Motion.root.join("app/javascript")
        imports = JSON.parse(Rails.application.importmap.to_json(resolver: PathResolver.new))["imports"]
        pinned = imports.values.map { |url| url.delete_prefix("/") }
        files = Dir.glob("poetry/motion{,-kernel}/**/*.js", base: javascript)

        assert_empty files - pinned, "files with no importmap pin"
      end

      def test_every_pinned_file_exists
        javascript = Poetry::Motion.root.join("app/javascript")

        Rails.application.importmap.packages.each_value do |package|
          next unless package.path.start_with?("poetry/motion")

          assert_path_exists javascript.join(package.path)
        end
      end

      def test_the_tokens_stylesheet_carries_every_token_the_policy_reads
        css = Poetry::Motion.root.join("app/assets/stylesheets/poetry-motion.css").read

        %w[duration-fast duration-normal duration-slow ease-standard ease-emphasized ease-exit
           spring-gentle spring-snappy spring-bouncy].each do |name|
          assert_match(/--motion-#{name}:/, css)
        end
      end

      # Resolves an importmap path to a URL the way a host's asset helper would.
      class PathResolver
        def path_to_asset(path) = "/#{path}"
      end
    end
  end
end
