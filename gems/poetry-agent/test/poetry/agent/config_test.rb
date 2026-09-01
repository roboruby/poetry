# frozen_string_literal: true

require "test_helper"

module Poetry
  module Agent
    class ConfigTest < Minitest::Test
      # The budget lives on poetry-core's configuration (the component
      # contract puts it on every opted-in root); the gem's setting writes
      # through so the documented initializer keeps working.
      def test_registration_budget_writes_through_to_core
        config = Poetry::Agent.config

        assert_equal 20, config.registration_budget

        config.registration_budget = 12

        assert_equal 12, Poetry::Core::Config.current.webmcp_registration_budget
        assert_equal 12, config.registration_budget
      ensure
        config.registration_budget = 20
      end
    end
  end
end
