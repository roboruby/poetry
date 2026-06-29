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

        def test_call_returns_the_block_content
          render_inline(Poetry::Core::Wrapper::Component.new(Child.new)) { "wrapped!" }

          assert_includes rendered_content, "wrapped!"
        end

        def test_double_render_raises
          wrapper = Poetry::Core::Wrapper::Component.new(Child.new)
          # Simulate a first render having already happened.
          wrapper.instance_variable_set(:@rendered, "already")

          assert_raises(Poetry::Core::Wrapper::Component::DoubleRenderError) do
            wrapper.component
          end
        end

        def test_double_render_error_is_a_standard_error
          assert_operator Poetry::Core::Wrapper::Component::DoubleRenderError, :<, StandardError
        end
      end
    end
  end
end
