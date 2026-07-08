# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module Concerns
      class IntrospectionTest < Minitest::Test
        # A component exercising every prop-definition shape: static, proc,
        # and absent defaults; required; booleans; options; formats; both
        # slot kinds, typed and untyped.
        module Probe
          class Glyph < Poetry::Core::Component
            option :name, :symbol, required: true, format: :"icon-name"

            def call
              content_tag(:span, "glyph")
            end
          end

          class Component < Poetry::Core::Component
            style :color, default: :gray, required: true, variants: %i[gray red]
            style :dot_color, default: -> { color }, variants: %i[gray red]
            style :outlined, variants: :boolean, default: false
            option :label, :string
            option :count, :integer, default: 3

            renders_one :icon
            renders_many :items
            renders_one :badge, Glyph
            # House style: every polymorphic type declares as: matching its
            # key, so the registry's type list IS the setter list (any
            # divergence falls into slot_extras and stays valid anyway).
            renders_many :entries, types: {
              row: { renders: ->(**) { "row" }, as: :row },
              divider: { renders: ->(**) { "divider" }, as: :divider }
            }

            # A hand-rolled convenience beyond the registered slots - part
            # of the consumer call surface (the NavigationMenu#with_link
            # shape).
            def with_shortcut(text)
              with_row { text }
            end

            def call
              content_tag(:span, "probe")
            end
          end
        end

        def props
          Probe::Component.prop_definitions
        end

        def test_style_definitions_carry_variants_defaults_and_required
          color = props[:styles].find { |style| style[:name] == :color }

          assert_equal :symbol, color[:type]
          assert_equal %i[gray red], color[:variants]
          assert_equal :gray, color[:default]
          assert color[:required]
        end

        def test_proc_defaults_are_marked_dynamic_not_evaluated
          dot = props[:styles].find { |style| style[:name] == :dot_color }

          assert_equal Introspection::DYNAMIC_DEFAULT, dot[:default]
        end

        def test_boolean_styles_report_boolean_type_and_false_default
          outlined = props[:styles].find { |style| style[:name] == :outlined }

          assert_equal :boolean, outlined[:type]
          # rubocop:disable Minitest/RefuteFalse -- refute would also pass for nil; this pins the literal false
          assert_equal false, outlined[:default], "a false default must not be dropped"
          # rubocop:enable Minitest/RefuteFalse
          refute outlined.key?(:variants), ":boolean is a type, not a variant list"
        end

        def test_option_definitions_carry_type_and_default_presence
          label = props[:options].find { |option| option[:name] == :label }
          count = props[:options].find { |option| option[:name] == :count }

          assert_equal :string, label[:type]
          refute label.key?(:default), "no default declared means no default key"
          assert_equal 3, count[:default]
        end

        def test_slot_definitions_distinguish_one_from_many
          slots = props[:slots]

          assert_includes slots, { name: :icon, many: false }
          assert_includes slots, { name: :items, many: true }
        end

        def test_a_declared_format_is_carried_and_absence_stays_absent
          name = Probe::Glyph.prop_definitions[:options].find { |option| option[:name] == :name }
          label = props[:options].find { |option| option[:name] == :label }

          assert_equal :"icon-name", name[:format]
          refute label.key?(:format), "no format declared means no format key"
        end

        def test_a_typed_slot_carries_its_component_path
          badge = props[:slots].find { |slot| slot[:name] == :badge }
          icon = props[:slots].find { |slot| slot[:name] == :icon }

          assert_equal Probe::Glyph.component_path, badge[:component]
          refute icon.key?(:component), "an untyped slot has no component to point at"
        end

        def test_a_polymorphic_slot_carries_its_type_setters
          entries = props[:slots].find { |slot| slot[:name] == :entries }
          icon = props[:slots].find { |slot| slot[:name] == :icon }

          assert_equal %i[row divider], entries[:types]
          refute icon.key?(:types), "a plain slot has no types"
        end

        def test_hand_rolled_with_conveniences_surface_as_slot_extras
          assert_equal ["shortcut"], props[:slot_extras]
          assert_empty Probe::Glyph.prop_definitions[:slot_extras]
        end

        def test_x_component_full_surface
          styles = Poetry::Core::X::Component.prop_definitions[:styles]

          assert_equal %i[color mode shape size], styles.map { |s| s[:name] }.sort
          assert(styles.all? { |s| s[:required] })
        end
      end
    end
  end
end
