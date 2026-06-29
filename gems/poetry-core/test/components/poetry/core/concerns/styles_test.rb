# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module Concerns
      class StylesTest < ViewComponent::TestCase
        # Test component with basic style attributes
        class BasicComponent < Poetry::Core::Component
          style :color, default: :primary, variants: %i[primary secondary success]
          style :size, default: :md, variants: %i[sm md lg]
        end

        # Test component with proc defaults
        class ProcDefaultComponent < Poetry::Core::Component
          style :color, default: :red, variants: %i[red blue green]
          style :dot_color, default: -> { color }, variants: %i[red blue green]
        end

        # Test component with required attributes
        class RequiredComponent < Poetry::Core::Component
          style :type, required: true, variants: %i[button link]
        end

        # Test component with boolean attributes
        class BooleanComponent < Poetry::Core::Component
          style :outlined, variants: :boolean, default: false
        end

        # Basic style attribute tests
        def test_defines_style_attributes
          component = BasicComponent.new

          assert_equal :primary, component.color
          assert_equal :md, component.size
        end

        def test_overrides_default_values
          component = BasicComponent.new(color: :secondary, size: :lg)

          assert_equal :secondary, component.color
          assert_equal :lg, component.size
        end

        def test_validates_against_variants
          component = BasicComponent.new(color: :invalid)

          assert_not component.valid?
          assert_predicate component.errors[:color], :any?
        end

        def test_required_attributes_validation
          component = RequiredComponent.new

          assert_not component.valid?
          assert_predicate component.errors[:type], :any?

          component_with_type = RequiredComponent.new(type: :button)

          assert_predicate component_with_type, :valid?
        end

        def test_boolean_attributes
          component = BooleanComponent.new

          refute component.outlined

          component = BooleanComponent.new(outlined: true)

          assert component.outlined
        end

        # Class method tests
        def test_style_attributes_returns_all_attributes
          assert_equal %i[color size], BasicComponent.style_attributes
        end

        def test_style_attributes_with_defaults
          assert_equal %i[color size], BasicComponent.style_attributes_with_defaults
        end

        def test_style_attributes_with_static_defaults
          assert_equal %i[color size], BasicComponent.style_attributes_with_static_defaults
          assert_equal [:color], ProcDefaultComponent.style_attributes_with_static_defaults
        end

        def test_style_attributes_with_proc_defaults
          assert_equal [], BasicComponent.style_attributes_with_proc_defaults
          assert_equal [:dot_color], ProcDefaultComponent.style_attributes_with_proc_defaults
        end

        def test_has_style_attribute
          assert BasicComponent.has_style_attribute?(:color)
          assert BasicComponent.has_style_attribute?(:size)
          assert_not BasicComponent.has_style_attribute?(:nonexistent)
        end

        def test_style_variants_getter
          assert_equal %i[primary secondary success], BasicComponent.color_variants
          assert_equal %i[sm md lg], BasicComponent.size_variants
        end

        # Instance method tests
        def test_style_attribute_check
          component = BasicComponent.new

          assert component.style_attribute?(:color)
          assert_not component.style_attribute?(:nonexistent)
        end

        def test_initialized_style_attributes
          component = BasicComponent.new(color: :secondary)
          # Both color (explicitly set) and size (has static default) are marked as initialized
          assert_includes component.initialized_style_attributes, :color
          assert_includes component.initialized_style_attributes, :size
        end

        def test_style_attribute_initialized
          component = BasicComponent.new(color: :secondary)
          # Both are marked as initialized (color explicitly, size via static default)
          assert component.style_attribute_initialized?(:color)
          assert component.style_attribute_initialized?(:size)
        end

        def test_style_attributes_status
          component = BasicComponent.new(color: :secondary)
          status = component.style_attributes_status
          # Both attributes have static defaults, so both are marked as initialized
          assert status[:color]
          assert status[:size]
        end

        def test_styles_returns_all_values
          component = BasicComponent.new(color: :secondary)
          styles = component.styles

          assert_equal :secondary, styles[:color]
          assert_equal :md, styles[:size]
        end

        # Proc default tests
        def test_proc_default_inherits_from_source_attribute
          component = ProcDefaultComponent.new(color: :red)

          assert_equal :red, component.color
          assert_equal :red, component.dot_color
        end

        def test_proc_default_can_be_overridden
          component = ProcDefaultComponent.new(color: :red, dot_color: :blue)

          assert_equal :red, component.color
          assert_equal :blue, component.dot_color
        end

        def test_proc_default_follows_source_attribute_changes
          component = ProcDefaultComponent.new(color: :red)

          assert_equal :red, component.dot_color

          component.color = :blue
          # dot_color was never explicitly set, so it should still follow color
          assert_equal :blue, component.dot_color
        end

        def test_proc_default_after_explicit_set_doesnt_follow_source
          component = ProcDefaultComponent.new(color: :red, dot_color: :green)

          assert_equal :red, component.color
          assert_equal :green, component.dot_color

          component.color = :blue
          # dot_color was explicitly set, so it shouldn't change
          assert_equal :green, component.dot_color
        end

        def test_proc_default_appears_in_attributes_hash_after_access
          component = ProcDefaultComponent.new(color: :blue)
          # Access dot_color to trigger proc evaluation
          assert_equal :blue, component.dot_color
          # Now it should appear in the attributes hash
          assert_equal :blue, component.attributes["dot_color"]
        end

        def test_proc_default_in_attributes_without_explicit_access
          component = ProcDefaultComponent.new(color: :red)
          # Calling .attributes automatically evaluates proc defaults
          # so dot_color should already be :red even without explicitly accessing it
          assert_equal :red, component.attributes["dot_color"]
        end

        def test_proc_default_respects_initialization_tracking
          component = ProcDefaultComponent.new(color: :red)
          # dot_color is not explicitly initialized
          assert_not component.style_attribute_initialized?(:dot_color)

          # But color is
          assert component.style_attribute_initialized?(:color)

          # Now set dot_color explicitly
          component.dot_color = :blue

          assert component.style_attribute_initialized?(:dot_color)
        end
      end
    end
  end
end
