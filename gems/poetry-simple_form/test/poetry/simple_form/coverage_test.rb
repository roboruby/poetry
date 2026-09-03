# frozen_string_literal: true

require "test_helper"

module Poetry
  module SimpleForm
    # The parity gate: every form-facing poetry component (a registry
    # component declaring a name: option) must be reachable through a
    # simple_form type, or be exempted in BRIDGE_EXEMPT with a reason - so a
    # new ui component cannot ship without a bridge decision, the way it
    # cannot ship without a FormBuilder decision.
    class CoverageTest < ActiveSupport::TestCase
      # name: is the glyph on Icon, not a form field.
      NAME_IS_NOT_A_FIELD = %w[icon].freeze

      def test_every_form_facing_component_is_reachable_from_a_simple_form_type
        reachable = COVERAGE.values.grep(String).uniq
        missing = form_facing_components - reachable - BRIDGE_EXEMPT.keys.map(&:to_s)

        assert_empty missing, "form-facing poetry components with no simple_form as: type (map them in " \
                              "Poetry::SimpleForm::INPUTS/COVERAGE or exempt them with a reason): #{missing.inspect}"
      end

      def test_coverage_names_only_real_form_facing_components
        stale = COVERAGE.values.grep(String).uniq - form_facing_components

        assert_empty stale, "COVERAGE names components that are not form-facing registry components: #{stale.inspect}"
      end

      def test_the_input_table_and_the_coverage_table_agree
        assert_equal INPUTS.keys.sort, COVERAGE.keys.sort
        assert_empty STOCK.keys & INPUTS.keys, "stock-only types must not be mapped"
      end

      def test_activate_installs_exactly_the_input_table
        mappings = ::SimpleForm::FormBuilder.mappings

        INPUTS.each do |type, klass|
          assert_equal klass, mappings[type], "simple_form's #{type} must resolve to #{klass}"
        end
      end

      private

      def form_facing_components
        Poetry::Core::Registry.new(source_root: Poetry::Ui.root).components.filter_map do |klass|
          next unless klass.respond_to?(:prop_definitions)
          next unless klass.prop_definitions[:options].any? { |option| option[:name] == :name }

          klass.name.sub("Poetry::Ui::", "").sub(/(::)?Component\z/, "").split("::").map(&:underscore).join("_")
        end.uniq - NAME_IS_NOT_A_FIELD
      end
    end
  end
end
