# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module Concerns
      class BehaviorsTest < ViewComponent::TestCase
        module Ruled
          extend Poetry::Core::Behavior

          behavior :ruled, "A rule-only behavior for the test.", runtime: true
          agent_rule "Follow the ruled behavior."

          contributes do |base, **|
            base.part "ruled-mark", "A part the behavior adds"
          end
        end

        class ListComponent < Poetry::Core::Component
          AGENT_RULES = ["The component's own rule."].freeze

          use_behavior Ruled

          use_stimulus do
            on :list do
              behavior :roving_focus, orientation: :option, loop: true
              controller(:tabs) { action :focus_activate, on: event(:roving_focus, :entry) }
            end
          end

          option :orientation, :symbol, default: :horizontal

          def call = tag.div("list", **stimulus_attributes_for(:list))
        end

        class ReplacingComponent < ListComponent
          use_stimulus do
            on(:list) { controller(:tabs) { register } }
          end
        end

        class ExtendingComponent < ListComponent
          use_stimulus do
            on(:list, extend: true) { controller(:tabs) { register } }
          end
        end

        class GridComponent < Poetry::Core::Component
          use_stimulus { on(:grid) { controller(:tag_group) { register } } }
          use_behavior :roving_focus, on: :grid, orientation: :horizontal

          def call = tag.div("grid", **stimulus_attributes_for(:grid))
        end

        def test_a_behavior_wires_its_element_in_declaration_order
          list = render_inline(ListComponent.new(orientation: :vertical)).at_css("div")

          assert_equal "poetry--core--roving-focus", list["data-controller"]
          assert_equal "vertical", list["data-poetry--core--roving-focus-orientation-value"]
          assert_equal "true", list["data-poetry--core--roving-focus-loop-value"]
          assert_nil list["data-poetry--core--roving-focus-manage-tabindex-value"]
          assert_equal "keydown->poetry--core--roving-focus#keydown " \
                       "poetry--core--roving-focus:entry->poetry--core--tabs#focusActivate", list["data-action"]
        end

        def test_the_registry_projection_names_each_behavior_once
          assert_equal [
            { "name" => "ruled", "description" => "A rule-only behavior for the test.", "runtime" => true },
            { "name" => "roving_focus", "description" => Poetry::Core::Behaviors::RovingFocus.behavior_description,
              "elements" => ["list"] }
          ], ListComponent.behavior_definitions
        end

        def test_behavior_rules_lead_the_components_own
          assert_equal ["Follow the ruled behavior.", "The component's own rule."], ListComponent.agent_rules
        end

        def test_contributions_run_on_the_using_class
          assert_includes ListComponent.part_definitions.map { |part| part["name"] }, "ruled-mark"
        end

        def test_a_redeclared_element_drops_its_inherited_behavior_and_an_extended_one_keeps_it
          names = ->(component) { component.behavior_definitions.map { |definition| definition["name"] } }

          assert_equal %w[ruled], names.call(ReplacingComponent)
          assert_equal %w[ruled roving_focus], names.call(ExtendingComponent)
        end

        def test_use_behavior_on_an_element_appends_the_wiring
          grid = render_inline(GridComponent.new).at_css("div")

          assert_equal "poetry--core--tag-group poetry--core--roving-focus", grid["data-controller"]
        end

        def test_misuse_raises_at_class_load
          errors = {
            "unknown" => -> { Class.new(Poetry::Core::Component) { use_behavior :no_such_behavior } },
            "on: the element" => -> { Class.new(Poetry::Core::Component) { use_behavior :roving_focus } },
            "wires nothing" => lambda {
              Class.new(Poetry::Core::Component) { use_stimulus { on(:root) { behavior :dismissable } } }
            },
            "unknown keyword" => lambda {
              Class.new(Poetry::Core::Component) { use_stimulus { on(:root) { behavior :roving_focus, speed: 2 } } }
            },
            "used twice" => -> { Class.new(Poetry::Core::Component) { 2.times { use_behavior :dismissable } } }
          }
          errors.each do |message, declare|
            error = assert_raises(Poetry::Core::Error) { declare.call }
            assert_match message, error.message
          end
        end

        def test_a_name_two_namespaces_define_is_ambiguous
          Poetry::Core::Behavior.namespaces << "Poetry::Core::Concerns::BehaviorsTest::Shadow"
          shadow = Module.new do
            extend Poetry::Core::Behavior

            behavior :roving_focus, "A shadowing behavior."
          end
          self.class.const_set(:Shadow, Module.new.tap { |mod| mod.const_set(:RovingFocus, shadow) })

          error = assert_raises(Poetry::Core::Behavior::Error) { Poetry::Core::Behavior.resolve(:roving_focus) }
          assert_match "ambiguous", error.message
        ensure
          Poetry::Core::Behavior.namespaces.delete("Poetry::Core::Concerns::BehaviorsTest::Shadow")
          self.class.send(:remove_const, :Shadow) if self.class.const_defined?(:Shadow, false)
        end
      end
    end
  end
end
