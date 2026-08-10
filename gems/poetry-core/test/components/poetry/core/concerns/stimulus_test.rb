# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module Concerns
      class StimulusTest < ViewComponent::TestCase
        # Real manifest controllers keep declaration-time validation live:
        # accordion (values type/collapsible, method toggle, event :change)
        # and action-bar (target count, value label, methods clear/keydown).
        # "connect"/"disconnect" exist on BOTH - the ambiguity fixture.
        class DeclaredComponent < Poetry::Core::Component
          use_stimulus do
            on :root do
              controller :accordion do
                register
                value :type
                value :collapsible, true
                action :toggle, on: :click
              end
            end
            on :list do
              controller :action_bar do
                register
                value :label, from: :label_text
                target :count
                action :keydown, on: :keydown, at: :window
              end
            end
          end

          def type = "single"
          def label_text = "3 chosen"

          def call
            tag.div("declared", **stimulus_attributes_for(:root))
          end
        end

        def test_declared_element_matches_hand_built_builder_output
          expected = build_attributes do |attrs|
            accordion = Poetry::Core::Stimulus::Builder.new("poetry--core--accordion", attrs)
            accordion.register_controller
            accordion.with_value(:type, "single")
            accordion.with_value(:collapsible, true)
            accordion.with_action(:toggle, on: :click)
          end

          assert_equal expected, DeclaredComponent.new.stimulus_attributes_for(:root)
        end

        def test_value_sources_implicit_literal_and_from
          expected = build_attributes do |attrs|
            bar = Poetry::Core::Stimulus::Builder.new("poetry--core--action-bar", attrs)
            bar.register_controller
            bar.with_value(:label, "3 chosen")
            bar.with_target(:count)
            bar.with_action(:keydown, on: :keydown, at: :window)
          end

          assert_equal expected, DeclaredComponent.new.stimulus_attributes_for(:list)
        end

        def test_renders_through_the_template
          html = render_inline(DeclaredComponent.new).to_html

          assert_includes html, 'data-controller="poetry--core--accordion"'
          assert_includes html, "declared"
        end

        def test_undeclared_element_raises_with_declared_names
          error = assert_raises(ArgumentError) { DeclaredComponent.new.stimulus_attributes_for(:nope) }
          assert_match(/undeclared stimulus element :nope/, error.message)
          assert_match(/root, list/, error.message)
        end

        class TwoControllerComponent < Poetry::Core::Component
          use_stimulus do
            on :root do
              controller(:accordion) { register }
              controller(:action_bar) { register }
            end
          end

          def call = tag.div("two", **stimulus_attributes_for(:root))
        end

        def test_two_controllers_share_one_attributes_instance
          expected = build_attributes do |attrs|
            Poetry::Core::Stimulus::Builder.new("poetry--core--accordion", attrs).register_controller
            Poetry::Core::Stimulus::Builder.new("poetry--core--action-bar", attrs).register_controller
          end

          assert_equal expected, TwoControllerComponent.new.stimulus_attributes_for(:root)

          html = render_inline(TwoControllerComponent.new).to_html

          assert_includes html, 'data-controller="poetry--core--accordion poetry--core--action-bar"'
        end

        class ConditionalComponent < Poetry::Core::Component
          option :enabled, :boolean, default: false
          option :extras, :boolean, default: false

          use_stimulus do
            on :root do
              controller :accordion, if: :enabled do
                register
                value :type, "single", unless: -> { extras }
                action :toggle, on: :click, if: :extras
              end
            end
            on :panel, if: :extras do
              controller(:action_bar) { register }
            end
          end

          def call = tag.div("cond", **stimulus_attributes_for(:root))
        end

        def test_controller_condition_gates_the_whole_wiring
          assert_equal({}, ConditionalComponent.new(enabled: false).stimulus_attributes_for(:root))
        end

        def test_entry_conditions_gate_individual_entries
          expected = build_attributes do |attrs|
            accordion = Poetry::Core::Stimulus::Builder.new("poetry--core--accordion", attrs)
            accordion.register_controller
            accordion.with_value(:type, "single")
          end

          assert_equal expected, ConditionalComponent.new(enabled: true).stimulus_attributes_for(:root)

          flipped = build_attributes do |attrs|
            accordion = Poetry::Core::Stimulus::Builder.new("poetry--core--accordion", attrs)
            accordion.register_controller
            accordion.with_action(:toggle, on: :click)
          end

          assert_equal flipped,
                       ConditionalComponent.new(enabled: true, extras: true).stimulus_attributes_for(:root)
        end

        def test_element_condition_returns_empty_hash
          assert_equal({}, ConditionalComponent.new.stimulus_attributes_for(:panel))
          refute_empty ConditionalComponent.new(extras: true).stimulus_attributes_for(:panel)
        end

        class ParentComponent < Poetry::Core::Component
          use_stimulus do
            on :root do
              controller :accordion do
                register
                value :type, "single"
              end
            end
            on :list do
              controller(:action_bar) { register }
            end
          end

          def call = tag.div("parent", **stimulus_attributes_for(:root))
        end

        class ReplacingChildComponent < ParentComponent
          use_stimulus do
            on :root do
              controller(:action_bar) { register }
            end
          end
        end

        class ExtendingChildComponent < ParentComponent
          use_stimulus do
            on :root, extend: true do
              controller(:action_bar) { register }
            end
          end
        end

        def test_subclass_redeclaration_replaces_the_element_wholesale
          expected = build_attributes do |attrs|
            Poetry::Core::Stimulus::Builder.new("poetry--core--action-bar", attrs).register_controller
          end

          assert_equal expected, ReplacingChildComponent.new.stimulus_attributes_for(:root)
        end

        def test_untouched_elements_inherit
          expected = build_attributes do |attrs|
            Poetry::Core::Stimulus::Builder.new("poetry--core--action-bar", attrs).register_controller
          end

          assert_equal expected, ReplacingChildComponent.new.stimulus_attributes_for(:list)
        end

        def test_extend_true_merges_into_the_inherited_element
          expected = build_attributes do |attrs|
            accordion = Poetry::Core::Stimulus::Builder.new("poetry--core--accordion", attrs)
            accordion.register_controller
            accordion.with_value(:type, "single")
            Poetry::Core::Stimulus::Builder.new("poetry--core--action-bar", attrs).register_controller
          end

          assert_equal expected, ExtendingChildComponent.new.stimulus_attributes_for(:root)
        end

        def test_parent_declarations_are_untouched_by_subclasses
          expected = build_attributes do |attrs|
            accordion = Poetry::Core::Stimulus::Builder.new("poetry--core--accordion", attrs)
            accordion.register_controller
            accordion.with_value(:type, "single")
          end

          assert_equal expected, ParentComponent.new.stimulus_attributes_for(:root)
        end

        def test_escape_hatch_shares_one_attributes_instance
          component = DeclaredComponent.new
          expected = build_attributes do |attrs|
            accordion = Poetry::Core::Stimulus::Builder.new("poetry--core--accordion", attrs)
            accordion.register_controller
            host = Poetry::Core::Stimulus::Builder.new("checkout", attrs)
            host.register_controller
            host.with_value(:total, 42)
          end

          actual = component.stimulus_attributes(:accordion, "checkout") do |accordion, checkout|
            accordion.register_controller
            checkout.register_controller
            checkout.with_value(:total, 42)
          end

          assert_equal expected, actual
        end

        def test_escape_hatch_requires_a_controller
          assert_raises(ArgumentError) { DeclaredComponent.new.stimulus_attributes }
        end

        def test_stimulus_action_resolves_unambiguous_methods
          assert_equal "poetry--core--accordion#toggle", DeclaredComponent.new.stimulus_action(:toggle)
        end

        def test_stimulus_action_raises_on_ambiguity
          error = assert_raises(ArgumentError) { DeclaredComponent.new.stimulus_action(:connect) }
          assert_match(/ambiguous action :connect/, error.message)
        end

        def test_stimulus_action_qualified_form
          assert_equal "poetry--core--action-bar#clear",
                       DeclaredComponent.new.stimulus_action(:action_bar, :clear)
        end

        def test_stimulus_action_validates_the_method
          assert_raises(Poetry::Core::Stimulus::Manifest::UnknownName) do
            DeclaredComponent.new.stimulus_action(:accordion, :vanish)
          end
        end

        def test_stimulus_event_resolves_and_validates
          assert_equal "poetry--core--accordion:change", DeclaredComponent.new.stimulus_event(:change)
          assert_raises(Poetry::Core::Stimulus::Declarations::DeclarationError) do
            DeclaredComponent.new.stimulus_event(:accordion, :vanished)
          end
        end

        class HostControllerComponent < Poetry::Core::Component
          use_stimulus do
            on :root do
              controller "checkout" do
                register
                value :anything_goes, "unvalidated"
                action :whatever, on: :click
              end
            end
          end

          def call = tag.div("host", **stimulus_attributes_for(:root))
        end

        def test_host_controllers_pass_through_unvalidated
          expected = build_attributes do |attrs|
            checkout = Poetry::Core::Stimulus::Builder.new("checkout", attrs)
            checkout.register_controller
            checkout.with_value(:anything_goes, "unvalidated")
            checkout.with_action(:whatever, on: :click)
          end

          assert_equal expected, HostControllerComponent.new.stimulus_attributes_for(:root)
        end

        class EventListeningComponent < Poetry::Core::Component
          use_stimulus do
            on :root do
              controller :action_bar do
                register
                action :keydown, on: event(:accordion, :change)
              end
            end
          end

          def call = tag.div("listens", **stimulus_attributes_for(:root))
        end

        def test_declared_event_names_wire_cross_controller_listens
          expected = build_attributes do |attrs|
            bar = Poetry::Core::Stimulus::Builder.new("poetry--core--action-bar", attrs)
            bar.register_controller
            bar.with_action(:keydown, on: "poetry--core--accordion:change")
          end

          assert_equal expected, EventListeningComponent.new.stimulus_attributes_for(:root)
        end

        def test_load_time_validation_of_value_names
          error = assert_raises(Poetry::Core::Stimulus::Declarations::DeclarationError) do
            Class.new(Poetry::Core::Component) do
              use_stimulus do
                on(:root) { controller(:accordion) { value :nope } }
              end
            end
          end
          assert_match(/unknown value "nope"/, error.message)
        end

        def test_load_time_validation_of_action_methods
          assert_raises(Poetry::Core::Stimulus::Declarations::DeclarationError) do
            Class.new(Poetry::Core::Component) do
              use_stimulus do
                on(:root) { controller(:accordion) { action :vanish, on: :click } }
              end
            end
          end
        end

        def test_load_time_validation_of_controllers
          error = assert_raises(Poetry::Core::Stimulus::Declarations::DeclarationError) do
            Class.new(Poetry::Core::Component) do
              use_stimulus do
                on(:root) { controller(:zzz_missing) { register } }
              end
            end
          end
          assert_match(/unknown stimulus controller :zzz_missing/, error.message)
        end

        def test_condition_options_are_validated
          error = assert_raises(Poetry::Core::Stimulus::Declarations::DeclarationError) do
            Class.new(Poetry::Core::Component) do
              use_stimulus do
                on(:root) { controller(:accordion) { value :type, wat: 1 } }
              end
            end
          end
          assert_match(/unknown option/, error.message)
        end

        class LiteralEdgeComponent < Poetry::Core::Component
          use_stimulus do
            on :root do
              controller :accordion do
                register
                value :collapsible, false
                action :toggle
              end
            end
          end

          def call = tag.div("edge", **stimulus_attributes_for(:root))
        end

        def test_false_literals_and_bare_actions_round_trip
          expected = build_attributes do |attrs|
            accordion = Poetry::Core::Stimulus::Builder.new("poetry--core--accordion", attrs)
            accordion.register_controller
            accordion.with_value(:collapsible, false)
            accordion.with_action(:toggle, on: nil)
          end

          assert_equal expected, LiteralEdgeComponent.new.stimulus_attributes_for(:root)
        end

        def test_use_stimulus_requires_a_block
          assert_raises(ArgumentError) { Class.new(Poetry::Core::Component) { use_stimulus } }
        end

        private

        def build_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          yield attrs
          attrs.to_attributes
        end
      end
    end
  end
end
