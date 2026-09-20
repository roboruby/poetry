# frozen_string_literal: true

require "test_helper"

module Poetry
  module Charts
    # The bootstrap proof: the gem loads inside a Rails host, the engine
    # mounts, and core's machinery (the component model the frame builds on)
    # is reachable. Real contracts arrive with the frame components.
    class SkeletonTest < ActiveSupport::TestCase
      def test_version_is_present
        assert_match(/\A\d+\.\d+\.\d+\z/, Poetry::Charts::VERSION)
      end

      def test_the_engine_is_mounted
        assert_operator Poetry::Charts::Engine, :<, Rails::Engine
        assert_includes Rails.application.railties.map(&:class), Poetry::Charts::Engine
      end

      def test_root_points_at_the_gem
        assert_predicate Poetry::Charts.root.join("poetry-charts.gemspec"), :exist?
      end

      def test_core_is_loaded
        assert defined?(Poetry::Core::Component), "poetry-core's component model must be reachable"
      end
    end
  end
end
