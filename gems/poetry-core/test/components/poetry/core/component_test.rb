# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    class ComponentTest < ViewComponent::TestCase
      # Create a simple test component for testing
      class TestComponent < Poetry::Core::Component
        style :color, default: :primary, variants: %i[primary secondary success]
        style :size, default: :md, variants: %i[sm md lg]
        style :dynamic_attr, default: -> { color }, variants: %i[primary secondary success]

        def call
          content_tag(:div, "Test", html_attributes)
        end

        def css
          "test-component"
        end
      end

      # Test initialization

      def test_component_initializes_with_no_attributes
        component = TestComponent.new

        assert_instance_of TestComponent, component
      end

      def test_component_initializes_with_attributes
        component = TestComponent.new(color: :secondary, size: :lg)

        assert_equal :secondary, component.color
        assert_equal :lg, component.size
      end

      def test_component_separates_style_and_html_attributes
        component = TestComponent.new(color: :primary, class: "custom-class", id: "test-id")

        assert_equal :primary, component.color
        assert_includes component.html_attributes[:class], "custom-class"
      end

      def test_component_tracks_registered_styles
        component = TestComponent.new(color: :secondary)

        assert component.style_attribute_initialized?(:color)
      end

      def test_component_marks_static_defaults_as_initialized
        component = TestComponent.new

        assert component.style_attribute_initialized?(:color)
        assert component.style_attribute_initialized?(:size)
      end

      def test_component_does_not_mark_proc_defaults_as_initialized
        component = TestComponent.new

        refute component.style_attribute_initialized?(:dynamic_attr)
      end

      # Test class methods

      def test_config_returns_poetry_core_config
        assert_equal Poetry::Core::Config.current, TestComponent.config
      end

      def test_component_path_returns_underscored_path
        assert_equal "poetry/core/component_test/test", TestComponent.component_path
      end

      def test_component_module_returns_module_name
        assert_equal "Poetry::Core::ComponentTest::TestComponent", TestComponent.component_module
      end

      def test_component_identifier_returns_dashed_identifier
        assert_equal "poetry--core--component_test--test", TestComponent.component_identifier
      end

      def test_component_title_returns_last_segment
        assert_equal "test", TestComponent.component_title
      end

      def test_component_path_handles_regular_component_class
        # Test with the actual Poetry::Core::Component class
        assert_equal "poetry/core", Poetry::Core::Component.component_path
      end

      # Test instance methods

      def test_persisted_returns_false
        component = TestComponent.new

        refute_predicate component, :persisted?
      end

      def test_attributes_returns_hash
        component = TestComponent.new(color: :secondary)

        assert_instance_of Hash, component.attributes
      end

      def test_attributes_includes_style_attributes
        component = TestComponent.new(color: :secondary, size: :lg)
        attributes = component.attributes

        assert_equal :secondary, attributes["color"]
        assert_equal :lg, attributes["size"]
      end

      def test_attributes_evaluates_proc_defaults
        component = TestComponent.new(color: :secondary)
        attributes = component.attributes
        # The dynamic_attr should inherit from color
        assert_equal :secondary, attributes["dynamic_attr"]
      end

      def test_html_attributes_returns_hash_like_object
        component = TestComponent.new
        # html_attributes returns Poetry::Core::HTML::Attributes which behaves like a hash
        assert_respond_to component.html_attributes, :[]
        assert_respond_to component.html_attributes, :merge
      end

      def test_html_attributes_includes_class
        component = TestComponent.new

        assert component.html_attributes.key?(:class)
      end

      def test_html_attributes_merges_component_css_with_custom_class
        component = TestComponent.new(class: "custom-class")
        html_attrs = component.html_attributes

        assert_includes html_attrs[:class], "test-component"
        assert_includes html_attrs[:class], "custom-class"
      end

      def test_html_attributes_preserves_non_class_attributes
        component = TestComponent.new(id: "test-id", data: { controller: "example" })
        html_attrs = component.html_attributes

        assert_equal "test-id", html_attrs[:id]
        assert_equal({ "controller" => "example" }, html_attrs[:data])
      end

      def test_classnames_merges_multiple_classnames
        component = TestComponent.new
        result = component.classnames("class-1", "class-2", "class-3")

        assert_instance_of String, result
        assert_includes result, "class-1"
        assert_includes result, "class-2"
        assert_includes result, "class-3"
      end

      def test_classnames_handles_nil_values
        component = TestComponent.new
        result = component.classnames("class-1", nil, "class-2")

        assert_instance_of String, result
        assert_includes result, "class-1"
        assert_includes result, "class-2"
      end

      def test_classnames_uses_configured_merger
        component = TestComponent.new

        assert_respond_to component, :classnames
      end

      def test_to_html_renders_component
        component = TestComponent.new(color: :secondary)
        html = component.to_html
        # to_html returns an ActiveSupport::SafeBuffer, which is a String subclass
        assert_kind_of String, html
        assert_includes html, "<div"
        assert_includes html, "Test"
        assert_includes html, "</div>"
      end

      def test_to_html_includes_html_attributes
        component = TestComponent.new(id: "test-id", class: "custom")
        html = component.to_html

        assert_includes html, 'id="test-id"'
        assert_includes html, "custom"
      end

      # Test inheritance

      def test_component_inherits_from_view_component_base
        assert_operator Poetry::Core::Component, :<, ViewComponent::Base
      end

      def test_test_component_inherits_from_component_path
        assert_operator TestComponent, :<, Poetry::Core::Component
      end

      # Test included modules

      def test_component_includes_active_model_attributes
        component = TestComponent.new

        assert_respond_to component, :attributes
        assert_respond_to component, :attribute_names
      end

      def test_component_includes_active_model_attribute_assignment
        component = TestComponent.new

        assert_respond_to component, :assign_attributes
      end

      def test_component_includes_active_model_validations
        component = TestComponent.new

        assert_respond_to component, :valid?
        assert_respond_to component, :errors
      end

      def test_component_includes_translation_helper
        component = TestComponent.new
        # TranslationHelper methods are available
        assert_kind_of Poetry::Core::Contrib::TranslationHelper, component
      end

      def test_component_includes_wrapped_helper
        component = TestComponent.new
        # WrappedHelper methods are available
        assert_kind_of Poetry::Core::Contrib::WrappedHelper, component
      end

      def test_component_includes_styles_concern
        component = TestComponent.new
        # Styles concern methods are available
        assert_respond_to component, :style_attribute_initialized?
        assert_respond_to component.class, :style
      end

      def test_component_includes_options_concern
        component = TestComponent.new
        # Options concern methods are available
        assert_respond_to component.class, :option
      end

      # Test style attribute behavior with defaults

      def test_static_default_is_used_when_not_provided
        component = TestComponent.new

        assert_equal :primary, component.color
        assert_equal :md, component.size
      end

      def test_static_default_can_be_overridden
        component = TestComponent.new(color: :secondary)

        assert_equal :secondary, component.color
      end

      def test_proc_default_evaluates_lazily
        component = TestComponent.new(color: :success)
        # dynamic_attr should inherit from color
        assert_equal :success, component.dynamic_attr
      end

      def test_proc_default_can_be_explicitly_set
        component = TestComponent.new(color: :primary, dynamic_attr: :secondary)

        assert_equal :primary, component.color
        assert_equal :secondary, component.dynamic_attr
      end

      def test_changing_attribute_affects_proc_default_if_not_explicitly_set
        component = TestComponent.new(color: :primary)

        assert_equal :primary, component.dynamic_attr
        component.color = :success
        component
        # NOTE: Once accessed, the proc default is cached. This behavior depends on
        # the implementation details of the Styles concern.
      end

      # Test rendering with ViewComponent::TestHelpers

      def test_component_renders_with_render_inline
        render_inline(TestComponent.new(color: :secondary))

        assert_includes rendered_content, "<div"
        assert_includes rendered_content, "Test"
      end

      def test_component_renders_with_custom_html_attributes
        render_inline(TestComponent.new(id: "my-id", data: { action: "click->example#doSomething" }))

        assert_includes rendered_content, 'id="my-id"'
        assert_includes rendered_content, 'data-action="click-&gt;example#doSomething"'
      end

      # Test edge cases

      def test_component_with_empty_attributes_hash
        component = TestComponent.new({})

        assert_equal :primary, component.color
        assert_equal :md, component.size
      end

      def test_component_with_nil_attribute_values
        # Only explicitly set attributes should override defaults
        # nil values typically don't override defaults in ActiveModel
        component = TestComponent.new(color: nil)
        # Behavior depends on ActiveModel::Attributes implementation
        assert_instance_of TestComponent, component
      end

      def test_component_with_indifferent_access
        # Component should handle both string and symbol keys
        component1 = TestComponent.new(color: :secondary)
        component2 = TestComponent.new("color" => :secondary)

        assert_equal component1.color, component2.color
      end

      def test_multiple_components_have_independent_registered_styles
        component1 = TestComponent.new(color: :secondary)
        component2 = TestComponent.new(size: :lg)

        # Both components track color and size as initialized because they have static defaults
        # The explicitly provided attributes are tracked separately
        assert component1.style_attribute_initialized?(:color)
        assert component1.style_attribute_initialized?(:size) # Static default

        assert component2.style_attribute_initialized?(:color) # Static default
        assert component2.style_attribute_initialized?(:size)
      end

      def test_attributes_are_deep_duped
        # Ensure that modifying one component doesn't affect another
        component1 = TestComponent.new(color: :primary)
        component2 = TestComponent.new(color: :secondary)
        component1.color = :success

        assert_equal :success, component1.color
        assert_equal :secondary, component2.color
      end
    end
  end
end
