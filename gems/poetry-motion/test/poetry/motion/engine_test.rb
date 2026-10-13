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

      def test_the_pinned_tree_preloads_and_leaves_the_engine_out
        pinned = Rails.application.importmap.preloaded_module_paths(resolver: PathResolver.new, cache_key: :motion)

        assert_includes pinned, "/poetry/motion/policy.js"
        assert_includes pinned, "/poetry/motion/load_engine.js"
        refute(pinned.any? { |pin| pin.include?("motion-kernel") }, "the engine preloads")
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
