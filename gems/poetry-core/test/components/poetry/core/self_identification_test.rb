# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    # The data-component / data-slot markup contract.
    class SelfIdentificationTest < Minitest::Test
      def test_component_data_attributes_carry_the_component_title
        assert_equal({ "data-component" => "x" }, Poetry::Core::X::Component.new.component_data_attributes)
      end

      def test_slot_data_attributes_carry_the_part_name
        component = Poetry::Core::X::Component.new

        assert_equal({ "data-slot" => "icon" }, component.slot_data_attributes(:icon))
      end
    end
  end
end
