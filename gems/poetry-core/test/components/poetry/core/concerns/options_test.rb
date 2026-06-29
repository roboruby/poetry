# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module Concerns
      class OptionsTest < ViewComponent::TestCase
        # Test component with basic option attributes
        class BasicComponent < Poetry::Core::Component
          option :title, :string, default: "Untitled"
          option :count, :integer, default: 0
          option :enabled, :boolean, default: true
        end

        # Test component with proc defaults
        class ProcDefaultComponent < Poetry::Core::Component
          option :name, :string, default: "Default Name"
          option :aria_label, :string, default: -> { name }
        end

        # Test component with required attributes
        class RequiredComponent < Poetry::Core::Component
          option :id, :string, required: true
        end

        # Test component with various types
        class TypedComponent < Poetry::Core::Component
          option :price, :decimal
          option :score, :float, default: 0.0
          option :created_at, :datetime
        end

        # Test component with inheritance
        class BaseComponent < Poetry::Core::Component
          option :base_option, :string, default: "base"
        end

        class ChildComponent < BaseComponent
          option :child_option, :string, default: "child"
        end

        # Basic option attribute tests
        def test_defines_option_attributes
          component = BasicComponent.new

          assert_equal "Untitled", component.title
          assert_equal 0, component.count
          assert component.enabled
        end

        def test_overrides_default_values
          component = BasicComponent.new(title: "Custom Title", count: 42, enabled: false)

          assert_equal "Custom Title", component.title
          assert_equal 42, component.count
          refute component.enabled
        end

        def test_type_coercion_string
          component = BasicComponent.new(title: 123)

          assert_equal "123", component.title
        end

        def test_type_coercion_integer
          component = BasicComponent.new(count: "42")

          assert_equal 42, component.count
        end

        def test_type_coercion_boolean
          # ActiveModel boolean coercion: "false", "0", nil, and false are falsy
          component = BasicComponent.new(enabled: "false")

          refute component.enabled

          component2 = BasicComponent.new(enabled: "true")

          assert component2.enabled

          component3 = BasicComponent.new(enabled: false)

          refute component3.enabled

          component4 = BasicComponent.new(enabled: true)

          assert component4.enabled
        end

        def test_required_attributes_validation
          component = RequiredComponent.new

          assert_not component.valid?
          assert_predicate component.errors[:id], :any?

          component_with_id = RequiredComponent.new(id: "unique-id")

          assert_predicate component_with_id, :valid?
        end

        # Type tests
        def test_decimal_type
          component = TypedComponent.new(price: "19.99")

          assert_equal BigDecimal("19.99"), component.price
        end

        def test_float_type
          component = TypedComponent.new(score: "9.5")

          assert_in_delta(9.5, component.score)
        end

        def test_datetime_type
          now = Time.zone.now
          component = TypedComponent.new(created_at: now)
          # ActiveModel datetime type returns Time or TimeWithZone depending on the input
          assert_respond_to component.created_at, :year
          assert_respond_to component.created_at, :month
          assert_respond_to component.created_at, :day
        end

        # Class method tests
        def test_option_attributes_returns_all_attributes
          assert_equal %i[count enabled title], BasicComponent.option_attributes
        end

        def test_option_attributes_with_defaults
          assert_equal %i[count enabled title], BasicComponent.option_attributes_with_defaults
        end

        def test_option_attributes_with_static_defaults
          assert_equal %i[count enabled title], BasicComponent.option_attributes_with_static_defaults
          assert_equal [:name], ProcDefaultComponent.option_attributes_with_static_defaults
        end

        def test_option_attributes_with_proc_defaults
          assert_equal [], BasicComponent.option_attributes_with_proc_defaults
          assert_equal [:aria_label], ProcDefaultComponent.option_attributes_with_proc_defaults
        end

        def test_has_option_attribute
          assert BasicComponent.has_option_attribute?(:title)
          assert BasicComponent.has_option_attribute?(:count)
          assert_not BasicComponent.has_option_attribute?(:nonexistent)
        end

        def test_option_type_getter_on_class
          assert_equal :string, BasicComponent.title_type
          assert_equal :integer, BasicComponent.count_type
          assert_equal :boolean, BasicComponent.enabled_type
        end

        def test_option_type_method
          assert_equal :string, BasicComponent.option_type(:title)
          assert_equal :integer, BasicComponent.option_type(:count)
          assert_equal :boolean, BasicComponent.option_type(:enabled)
          assert_nil BasicComponent.option_type(:nonexistent)
        end

        # Instance method tests
        def test_option_attribute_check
          component = BasicComponent.new

          assert component.option_attribute?(:title)
          assert_not component.option_attribute?(:nonexistent)
        end

        def test_initialized_option_attributes
          component = BasicComponent.new(title: "Custom")
          # All three have static defaults, so all three are marked as initialized
          assert_includes component.initialized_option_attributes, :title
          assert_includes component.initialized_option_attributes, :count
          assert_includes component.initialized_option_attributes, :enabled
        end

        def test_option_attribute_initialized
          component = BasicComponent.new(title: "Custom")
          # All three attributes have static defaults, so all are marked as initialized
          assert component.option_attribute_initialized?(:title)
          assert component.option_attribute_initialized?(:count)
          assert component.option_attribute_initialized?(:enabled)
        end

        def test_option_attributes_status
          component = BasicComponent.new(title: "Custom")
          status = component.option_attributes_status
          # All three attributes have static defaults, so all are marked as initialized
          assert status[:title]
          assert status[:count]
          assert status[:enabled]
        end

        def test_options_returns_all_values
          component = BasicComponent.new(title: "Custom")
          options = component.options

          assert_equal "Custom", options[:title]
          assert_equal 0, options[:count]
          assert options[:enabled]
        end

        # Proc default tests
        def test_proc_default_inherits_from_source_attribute
          component = ProcDefaultComponent.new(name: "John")

          assert_equal "John", component.name
          assert_equal "John", component.aria_label
        end

        def test_proc_default_can_be_overridden
          component = ProcDefaultComponent.new(name: "John", aria_label: "Custom Label")

          assert_equal "John", component.name
          assert_equal "Custom Label", component.aria_label
        end

        def test_proc_default_follows_source_attribute_changes
          component = ProcDefaultComponent.new(name: "John")

          assert_equal "John", component.aria_label

          component.name = "Jane"
          # aria_label was never explicitly set, so it should still follow name
          assert_equal "Jane", component.aria_label
        end

        def test_proc_default_after_explicit_set_doesnt_follow_source
          component = ProcDefaultComponent.new(name: "John", aria_label: "Custom Label")

          assert_equal "John", component.name
          assert_equal "Custom Label", component.aria_label

          component.name = "Jane"
          # aria_label was explicitly set, so it shouldn't change
          assert_equal "Custom Label", component.aria_label
        end

        def test_proc_default_appears_in_attributes_hash_after_access
          component = ProcDefaultComponent.new(name: "John")
          # Access aria_label to trigger proc evaluation
          assert_equal "John", component.aria_label
          # Now it should appear in the attributes hash
          assert_equal "John", component.attributes["aria_label"]
        end

        def test_proc_default_in_attributes_without_explicit_access
          component = ProcDefaultComponent.new(name: "John")
          # Calling .attributes automatically evaluates proc defaults
          # so aria_label should already be "John" even without explicitly accessing it
          assert_equal "John", component.attributes["aria_label"]
        end

        def test_proc_default_respects_initialization_tracking
          component = ProcDefaultComponent.new(name: "John")
          # aria_label is not explicitly initialized
          assert_not component.option_attribute_initialized?(:aria_label)

          # But name is
          assert component.option_attribute_initialized?(:name)

          # Now set aria_label explicitly
          component.aria_label = "Custom"

          assert component.option_attribute_initialized?(:aria_label)
        end

        # Inheritance tests
        def test_inheritance_collects_options_from_hierarchy
          assert_equal %i[base_option child_option], ChildComponent.option_attributes
        end

        def test_inheritance_with_defaults
          component = ChildComponent.new

          assert_equal "base", component.base_option
          assert_equal "child", component.child_option
        end

        def test_inheritance_option_types
          assert_equal :string, ChildComponent.option_type(:base_option)
          assert_equal :string, ChildComponent.option_type(:child_option)
        end

        # Integration tests with styles
        class MixedComponent < Poetry::Core::Component
          style :color, default: :primary, variants: %i[primary secondary]
          option :title, :string, default: "Title"
        end

        def test_can_use_both_styles_and_options
          component = MixedComponent.new(color: :secondary, title: "Custom")

          assert_equal :secondary, component.color
          assert_equal "Custom", component.title
        end

        def test_styles_and_options_tracked_separately
          component = MixedComponent.new(color: :secondary, title: "Custom")

          assert component.style_attribute_initialized?(:color)
          assert component.option_attribute_initialized?(:title)

          assert_includes component.style_attributes, :color
          assert_includes component.option_attributes, :title
          assert_not_includes component.style_attributes, :title
          assert_not_includes component.option_attributes, :color
        end

        def test_styles_and_options_return_correct_hashes
          component = MixedComponent.new(color: :secondary, title: "Custom")

          assert_equal({ color: :secondary }, component.styles)
          assert_equal({ title: "Custom" }, component.options)
        end
      end
    end
  end
end
