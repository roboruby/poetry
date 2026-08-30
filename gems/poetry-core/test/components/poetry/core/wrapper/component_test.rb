# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module Wrapper
      class ComponentTest < ViewComponent::TestCase
        # A minimal child whose render? is configurable.
        class Child < Poetry::Core::Component
          def initialize(renderable: true)
            @renderable = renderable
            super()
          end

          def render?
            @renderable
          end

          def call
            tag.span("child")
          end
        end

        def test_inherits_from_view_component_base
          assert_operator Poetry::Core::Wrapper::Component, :<, ViewComponent::Base
        end

        def test_delegates_render_to_the_child_component
          assert_predicate Poetry::Core::Wrapper::Component.new(Child.new(renderable: true)), :render?
          refute_predicate Poetry::Core::Wrapper::Component.new(Child.new(renderable: false)), :render?
        end

        def test_the_child_renders_inside_the_custom_markup
          html = render_inline(Poetry::Core::Wrapper::Component.new(Child.new)) do |wrapper|
            wrapper.helpers.content_tag(:div, wrapper.component, class: "custom")
          end

          assert_equal "child", html.css("div.custom span").first.text
        end

        def test_a_nonrenderable_child_skips_the_whole_wrapper
          render_inline(Poetry::Core::Wrapper::Component.new(Child.new(renderable: false))) do |wrapper|
            wrapper.helpers.content_tag(:div, wrapper.component, class: "custom")
          end

          assert_empty rendered_content
        end

        def test_rendering_the_child_twice_teaches
          error = assert_raises(Poetry::Core::Wrapper::Component::DoubleRenderError) do
            render_inline(Poetry::Core::Wrapper::Component.new(Child.new)) do |wrapper|
              wrapper.component + wrapper.component
            end
          end

          assert_includes error.message, "once"
        end

        def test_a_block_that_never_renders_the_child_teaches
          error = assert_raises(Poetry::Core::Wrapper::Component::UnrenderedChildError) do
            render_inline(Poetry::Core::Wrapper::Component.new(Child.new)) { "custom html only" }
          end

          assert_includes error.message, "#component"
        end

        def test_a_nil_child_teaches_at_construction
          error = assert_raises(ArgumentError) { Poetry::Core::Wrapper::Component.new(nil) }

          assert_includes error.message, "component instance"
        end

        def test_errors_join_the_family_taxonomy
          assert_operator Poetry::Core::Wrapper::Component::DoubleRenderError, :<, Poetry::Core::Error
          assert_operator Poetry::Core::Wrapper::Component::UnrenderedChildError, :<, Poetry::Core::Error
        end

        # -- the wrapped helper (Contrib::WrappedHelper, included in every component) --

        def test_wrapped_returns_a_wrapper_around_self
          child = Child.new
          wrapper = child.wrapped

          assert_instance_of Poetry::Core::Wrapper::Component, wrapper
          assert wrapper.component_instance.equal?(child), "wrapped must wrap the SAME instance"
        end

        def test_wrapped_renders_end_to_end
          html = render_inline(Child.new.wrapped) do |wrapper|
            wrapper.helpers.content_tag(:div, wrapper.component, class: "shell")
          end

          assert_equal "child", html.css("div.shell span").first.text
        end
      end
    end
  end
end
