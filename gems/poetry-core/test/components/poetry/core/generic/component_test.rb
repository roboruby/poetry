# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module Generic
      class ComponentTest < ViewComponent::TestCase
        def test_inherits_from_base_component
          assert_operator Poetry::Core::Generic::Component, :<, Poetry::Core::Component
        end

        def test_renders_a_content_tag_for_normal_tags
          render_inline(Poetry::Core::Generic::Component.new(html_tag: "strong")) { "Hello!" }

          assert_includes rendered_content, "<strong"
          assert_includes rendered_content, "Hello!"
          assert_includes rendered_content, "</strong>"
        end

        def test_renders_a_void_tag_for_self_closing_tags
          render_inline(Poetry::Core::Generic::Component.new(html_tag: "br"))

          assert_includes rendered_content, "<br"
          refute_includes rendered_content, "</br>"
        end

        def test_self_closing_tag_predicate
          component = Poetry::Core::Generic::Component.new(html_tag: "div")

          assert component.send(:self_closing_tag?, "img")
          assert component.send(:self_closing_tag?, :hr)
          refute component.send(:self_closing_tag?, "div")
        end

        def test_html_tag_is_a_plain_attribute
          component = Poetry::Core::Generic::Component.new(html_tag: "span")

          assert_equal "span", component.html_tag
        end
      end
    end
  end
end
