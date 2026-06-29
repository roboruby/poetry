# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module Concerns
      class StimulusTest < ViewComponent::TestCase
        # Test component with basic Stimulus controller
        class BasicComponent < Poetry::Core::Component
          include Poetry::Core::Concerns::Stimulus

          stimulated_with :dropdown

          def call
            tag.div("Basic", **html_attributes.to_attributes)
          end

          def css
            "basic-component"
          end
        end

        # Test component with controller configuration block
        class ConfiguredComponent < Poetry::Core::Component
          include Poetry::Core::Concerns::Stimulus

          stimulated_with :dropdown do |controller|
            controller.with_value(:open, false)
            controller.with_action(:toggle, on: :click)
          end

          def call
            tag.div("Configured", **html_attributes.to_attributes)
          end

          def css = "configured-component"
        end

        # Test component with conditional registration using method
        class ConditionalComponent < Poetry::Core::Component
          include Poetry::Core::Concerns::Stimulus

          attribute :enabled, :boolean, default: false

          stimulated_with :dropdown, if: :enabled? do |controller|
            controller.with_value(:open, false)
          end

          def enabled?
            !!enabled
          end

          def call
            tag.div("Conditional", **html_attributes.to_attributes)
          end

          def css = "conditional-component"
        end

        # Test component with unless condition
        class UnlessComponent < Poetry::Core::Component
          include Poetry::Core::Concerns::Stimulus

          attribute :disabled, :boolean, default: false

          stimulated_with :dropdown, unless: :disabled? do |controller|
            controller.with_value(:open, false)
          end

          def disabled?
            !!disabled
          end

          def call
            tag.div("Unless", **html_attributes.to_attributes)
          end

          def css = "unless-component"
        end

        # Test component with both if and unless conditions
        class MultiConditionComponent < Poetry::Core::Component
          include Poetry::Core::Concerns::Stimulus

          attribute :enabled, :boolean, default: false
          attribute :disabled, :boolean, default: false

          stimulated_with :dropdown, if: :enabled?, unless: :disabled? do |controller|
            controller.with_value(:open, false)
          end

          def enabled?
            !!enabled
          end

          def disabled?
            !!disabled
          end

          def call
            tag.div("Multi", **html_attributes.to_attributes)
          end

          def css = "multi-condition-component"
        end

        # Test component with Proc conditions
        class ProcConditionComponent < Poetry::Core::Component
          include Poetry::Core::Concerns::Stimulus

          attribute :visible, :boolean, default: false

          stimulated_with :dropdown, if: -> { visible } do |controller|
            controller.with_value(:open, false)
          end

          def call
            tag.div("Proc", **html_attributes.to_attributes)
          end

          def css = "proc-condition-component"
        end

        # Test component with custom method name
        class CustomMethodComponent < Poetry::Core::Component
          include Poetry::Core::Concerns::Stimulus

          stimulated_with :dropdown, as: :menu do |controller|
            controller.with_value(:position, "bottom")
          end

          def call
            tag.div("Custom", **html_attributes.to_attributes)
          end

          def css = "custom-method-component"
        end

        # Test component with namespaced controller
        class NamespacedComponent < Poetry::Core::Component
          include Poetry::Core::Concerns::Stimulus

          stimulated_with [:poetry, :dropdown] do |controller|
            controller.with_value(:open, false)
          end

          def call
            tag.div("Namespaced", **html_attributes.to_attributes)
          end

          def css = "namespaced-component"
        end

        # Test component with multiple controllers
        class MultiControllerComponent < Poetry::Core::Component
          include Poetry::Core::Concerns::Stimulus

          stimulated_with :dropdown do |controller|
            controller.with_value(:open, false)
          end

          stimulated_with :tooltip do |controller|
            controller.with_value(:text, "Hello")
          end

          def call
            tag.div("Multi", **html_attributes.to_attributes)
          end

          def css = "multi-controller-component"
        end

        # Test component with register: false
        class DisabledComponent < Poetry::Core::Component
          include Poetry::Core::Concerns::Stimulus

          stimulated_with :dropdown, register: false do |controller|
            controller.with_value(:open, false)
          end

          def call
            tag.div("Disabled", **html_attributes.to_attributes)
          end

          def css = "disabled-component"
        end

        # Test component with initial options
        class InitialOptionsComponent < Poetry::Core::Component
          include Poetry::Core::Concerns::Stimulus

          stimulated_with :modal,
                          values: { open: false, size: "lg" },
                          classes: { active: "bg-blue-500" },
                          actions: { close: :click }

          def call
            tag.div("Initial", **html_attributes.to_attributes)
          end

          def css = "initial-options-component"
        end

        # Test component that accesses controller builder in before_render
        class DynamicComponent < Poetry::Core::Component
          include Poetry::Core::Concerns::Stimulus

          attribute :item_count, :integer, default: 0

          stimulated_with :dropdown do |controller|
            controller.with_value(:open, false)
          end

          def before_render
            dropdown_controller.with_value(:items, item_count)
            super
          end

          def call
            tag.div("Dynamic", **html_attributes.to_attributes)
          end

          def css = "dynamic-component"
        end

        # Component that uses stimulated directly
        class DirectAccessComponent < Poetry::Core::Component
          include Poetry::Core::Concerns::Stimulus

          def before_render
            stimulated.register("dropdown")
            super
          end

          def call
            tag.div("Direct", **html_attributes.to_attributes)
          end

          def css = "direct-access-component"
        end

        # Test concern inclusion
        def test_concern_can_be_included
          component = BasicComponent.new

          assert_kind_of Poetry::Core::Concerns::Stimulus, component
        end

        def test_includes_class_methods
          assert_respond_to BasicComponent, :stimulated_with
        end

        def test_includes_instance_methods
          component = BasicComponent.new

          assert_respond_to component, :stimulated
          assert_respond_to component, :before_render
        end

        # Test class_attribute setup
        def test_defines_stimulus_controllers_attribute
          assert_respond_to BasicComponent, :stimulus_controllers
        end

        def test_stimulus_controllers_is_hash
          assert_instance_of ActiveSupport::HashWithIndifferentAccess, BasicComponent.stimulus_controllers
        end

        def test_stimulus_controllers_is_empty_by_default
          test_component_class = Class.new(Poetry::Core::Component) do
            include Poetry::Core::Concerns::Stimulus
          end

          assert_empty test_component_class.stimulus_controllers
        end

        # Test stimulated_with class method
        def test_stimulated_with_registers_controller
          assert BasicComponent.stimulus_controllers.key?("dropdown")
        end

        def test_stimulated_with_stores_controller_instance
          controller = BasicComponent.stimulus_controllers["dropdown"]

          assert_instance_of Poetry::Core::Stimulus::Controller, controller
        end

        def test_stimulated_with_normalizes_identifier
          component_class = Class.new(Poetry::Core::Component) do
            include Poetry::Core::Concerns::Stimulus

            stimulated_with :my_controller
          end

          assert component_class.stimulus_controllers.key?("my-controller")
        end

        def test_stimulated_with_handles_array_identifier
          assert NamespacedComponent.stimulus_controllers.key?("poetry--dropdown")
        end

        def test_stimulated_with_defines_accessor_method
          component = BasicComponent.new

          assert_respond_to component, :dropdown_controller
        end

        def test_stimulated_with_accessor_method_returns_builder
          component = ConfiguredComponent.new
          render_inline(component)

          builder = component.dropdown_controller

          assert_instance_of Poetry::Core::Stimulus::Builder, builder
        end

        def test_stimulated_with_custom_method_name
          component = CustomMethodComponent.new

          assert_respond_to component, :menu_controller
          refute_respond_to component, :dropdown_controller
        end

        def test_stimulated_with_custom_method_name_returns_correct_builder
          component = CustomMethodComponent.new
          render_inline(component)

          builder = component.menu_controller

          assert_instance_of Poetry::Core::Stimulus::Builder, builder
          assert_equal "dropdown", builder.identifier
        end

        # Test multiple controllers
        def test_multiple_controllers_are_registered
          assert MultiControllerComponent.stimulus_controllers.key?("dropdown")
          assert MultiControllerComponent.stimulus_controllers.key?("tooltip")
        end

        def test_multiple_controllers_have_separate_methods
          component = MultiControllerComponent.new

          assert_respond_to component, :dropdown_controller
          assert_respond_to component, :tooltip_controller
        end

        # Test before_render hook
        def test_before_render_registers_controller
          component = BasicComponent.new
          render_inline(component)
          # After rendering, the controller should be registered
          assert component.stimulated.registered?("dropdown")
        end

        def test_before_render_executes_configuration_block
          component = ConfiguredComponent.new
          result = render_inline(component)

          html = result.to_html

          assert_includes html, 'data-dropdown-open-value="false"'
          assert_includes html, 'data-action="click->dropdown#toggle"'
        end

        def test_before_render_does_not_register_twice
          component = BasicComponent.new
          render_inline(component)

          # Manually check that controller is registered
          assert component.stimulated.registered?("dropdown")

          # Call before_render again (shouldn't raise error about duplicate registration)
          assert_nothing_raised do
            component.send(:before_render)
          end
        end

        def test_before_render_with_disabled_registration
          component = DisabledComponent.new
          render_inline(component)

          refute component.stimulated.registered?("dropdown")
        end

        # Test conditional registration
        def test_conditional_registration_with_false_condition
          component = ConditionalComponent.new(enabled: false)
          render_inline(component)

          refute component.stimulated.registered?("dropdown")
        end

        def test_conditional_registration_with_true_condition
          component = ConditionalComponent.new(enabled: true)
          render_inline(component)

          assert component.stimulated.registered?("dropdown")
        end

        def test_unless_condition_with_false
          component = UnlessComponent.new(disabled: false)
          render_inline(component)

          assert component.stimulated.registered?("dropdown")
        end

        def test_unless_condition_with_true
          component = UnlessComponent.new(disabled: true)
          render_inline(component)

          refute component.stimulated.registered?("dropdown")
        end

        def test_multiple_conditions_all_true
          component = MultiConditionComponent.new(enabled: true, disabled: false)
          render_inline(component)

          assert component.stimulated.registered?("dropdown")
        end

        def test_multiple_conditions_if_false
          component = MultiConditionComponent.new(enabled: false, disabled: false)
          render_inline(component)

          refute component.stimulated.registered?("dropdown")
        end

        def test_multiple_conditions_unless_true
          component = MultiConditionComponent.new(enabled: true, disabled: true)
          render_inline(component)

          refute component.stimulated.registered?("dropdown")
        end

        def test_proc_condition_with_false
          component = ProcConditionComponent.new(visible: false)
          render_inline(component)

          refute component.stimulated.registered?("dropdown")
        end

        def test_proc_condition_with_true
          component = ProcConditionComponent.new(visible: true)
          render_inline(component)

          assert component.stimulated.registered?("dropdown")
        end

        # Test initial options
        def test_initial_options_are_applied
          component = InitialOptionsComponent.new
          result = render_inline(component)

          html = result.to_html

          assert_includes html, 'data-modal-open-value="false"'
          assert_includes html, 'data-modal-size-value="lg"'
          assert_includes html, 'data-modal-active-class="bg-blue-500"'
          assert_includes html, 'data-action="click->modal#close"'
        end

        # Test dynamic configuration
        def test_dynamic_configuration_in_before_render
          component = DynamicComponent.new(item_count: 5)
          result = render_inline(component)

          html = result.to_html

          assert_includes html, 'data-dropdown-items-value="5"'
          assert_includes html, 'data-dropdown-open-value="false"'
        end

        # Test stimulated instance method
        def test_stimulated_returns_manager
          component = BasicComponent.new
          render_inline(component) # Render first to initialize html_attributes

          assert_instance_of Poetry::Core::Stimulus::Manager, component.stimulated
        end

        def test_stimulated_returns_same_instance
          component = BasicComponent.new
          render_inline(component) # Render first to initialize html_attributes
          manager1 = component.stimulated
          manager2 = component.stimulated

          assert_same manager1, manager2
        end

        def test_stimulated_manager_uses_html_attributes
          component = BasicComponent.new
          render_inline(component) # Render first to initialize html_attributes
          manager = component.stimulated
          # Manager uses the internal @html_attributes, not the merged html_attributes method
          assert_instance_of Poetry::Core::HTML::Attributes, manager.html_attributes
        end

        # Test direct access to stimulated
        def test_direct_access_to_stimulated
          component = DirectAccessComponent.new
          render_inline(component)

          assert component.stimulated.registered?("dropdown")
        end

        # Test integration with HTML attributes
        def test_controller_adds_data_controller_attribute
          component = BasicComponent.new
          result = render_inline(component)

          # Check the HTML output directly
          assert_includes result.to_html, 'data-controller="dropdown"'
        end

        def test_multiple_controllers_add_to_data_controller
          component = MultiControllerComponent.new
          result = render_inline(component)

          html = result.to_html

          assert_includes html, "dropdown"
          assert_includes html, "tooltip"
          assert_includes html, "data-controller="
        end

        def test_namespaced_controller_identifier
          component = NamespacedComponent.new
          result = render_inline(component)

          assert_includes result.to_html, 'data-controller="poetry--dropdown"'
        end

        # Test inheritance - use named test classes
        class ParentComponent < Poetry::Core::Component
          include Poetry::Core::Concerns::Stimulus

          stimulated_with :dropdown

          def call
            tag.div("Parent", **html_attributes.to_attributes)
          end

          def css = "parent-component"
        end

        class ChildComponent < ParentComponent
          stimulated_with :tooltip

          def call
            tag.div("Child", **html_attributes.to_attributes)
          end

          def css = "child-component"
        end

        class OverrideParentComponent < Poetry::Core::Component
          include Poetry::Core::Concerns::Stimulus

          stimulated_with :dropdown do |c|
            c.with_value(:open, false)
          end

          def call
            tag.div("OverrideParent", **html_attributes.to_attributes)
          end

          def css = "override-parent-component"
        end

        class OverrideChildComponent < OverrideParentComponent
          stimulated_with :dropdown do |c|
            c.with_value(:open, true)
          end

          def call
            tag.div("OverrideChild", **html_attributes.to_attributes)
          end

          def css = "override-child-component"
        end

        class ContextComponent < Poetry::Core::Component
          include Poetry::Core::Concerns::Stimulus

          attribute :message, :string, default: "Hello"

          stimulated_with :dropdown do |controller|
            controller.with_value(:message, message)
          end

          def call
            tag.div("Context", **html_attributes.to_attributes)
          end

          def css = "context-component"
        end

        class EmptyBlockComponent < Poetry::Core::Component
          include Poetry::Core::Concerns::Stimulus

          stimulated_with :dropdown do |_controller|
            # Empty block
          end

          def call
            tag.div("Empty", **html_attributes.to_attributes)
          end

          def css = "empty-block-component"
        end

        def test_controllers_are_inherited
          assert ChildComponent.stimulus_controllers.key?("dropdown")
          assert ChildComponent.stimulus_controllers.key?("tooltip")
        end

        def test_child_can_override_parent_controller
          parent_component = OverrideParentComponent.new
          child_component = OverrideChildComponent.new

          parent_result = render_inline(parent_component)
          child_result = render_inline(child_component)

          assert_includes parent_result.to_html, 'data-dropdown-open-value="false"'
          assert_includes child_result.to_html, 'data-dropdown-open-value="true"'
        end

        # Test configuration block has access to component context
        def test_configuration_block_has_component_context
          component = ContextComponent.new(message: "World")
          result = render_inline(component)

          assert_includes result.to_html, 'data-dropdown-message-value="World"'
        end

        # Edge cases
        def test_empty_configuration_block
          component = EmptyBlockComponent.new
          assert_nothing_raised do
            render_inline(component)
          end
        end

        def test_controller_without_block
          component = BasicComponent.new
          assert_nothing_raised do
            render_inline(component)
          end
        end

        # Test overriding same controller in same component
        class DuplicateControllerComponent < Poetry::Core::Component
          include Poetry::Core::Concerns::Stimulus

          stimulated_with :dropdown do |c|
            c.with_value(:open, false)
          end
          stimulated_with :dropdown do |c|
            c.with_value(:open, true)
          end

          def call
            tag.div("Duplicate", **html_attributes.to_attributes)
          end

          def css = "duplicate-controller-component"
        end

        def test_register_same_controller_twice_in_same_component
          component = DuplicateControllerComponent.new
          # Should not raise an error - the second declaration overrides the first
          result = nil
          assert_nothing_raised do
            result = render_inline(component)
          end
          # The second value should win
          assert_includes result.to_html, 'data-dropdown-open-value="true"'
        end
      end
    end
  end
end
