# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    class CoreTest < Minitest::Test
      def test_that_it_has_a_version_number
        refute_nil ::Poetry::Core::VERSION
      end
    end
  end
end
