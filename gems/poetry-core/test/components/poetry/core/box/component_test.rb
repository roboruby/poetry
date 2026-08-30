# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module Box
      class ComponentTest < ViewComponent::TestCase
        def test_renders_a_div_by_default
          html = render_inline(Component.new) { "content" }

          assert_equal "content", html.css("div").first.text
        end

        def test_renders_the_chosen_tag_with_content
          html = render_inline(Component.new(html_tag: "section")) { "Hello!" }

          assert_equal "Hello!", html.css("section").first.text
        end

        def test_symbol_tags_cast
          html = render_inline(Component.new(html_tag: :span)) { "inline" }

          assert_equal 1, html.css("span").length
        end

        def test_void_elements_self_close
          render_inline(Component.new(html_tag: "br"))

          assert_includes rendered_content, "<br"
          refute_includes rendered_content, "</br>"
        end

        def test_caller_attributes_land_on_the_element
          html = render_inline(Component.new(html_tag: "span", id: "note", class: "mt-2",
                                             data: { controller: "cart" })) { "x" }
          span = html.css("span").first

          assert_equal "note", span["id"]
          assert_includes span["class"], "mt-2"
          assert_includes span["data-controller"], "cart"
        end

        def test_the_element_self_identifies
          html = render_inline(Component.new(html_tag: "span")) { "x" }
          span = html.css("span").first

          assert_equal "box", span["data-slot"]
          assert_equal "box", span["data-component"]
        end

        def test_void_elements_carry_attributes_too
          html = render_inline(Component.new(html_tag: "hr", class: "my-6"))
          rule = html.css("hr").first

          assert_includes rule["class"], "my-6"
          assert_equal "box", rule["data-slot"]
        end

        def test_a_blank_tag_teaches
          error = assert_raises(ArgumentError) { render_inline(Component.new(html_tag: nil)) }

          assert_includes error.message, "Box requires html_tag:"
        end

        def test_a_malformed_tag_teaches
          error = assert_raises(ArgumentError) { render_inline(Component.new(html_tag: "no spaces")) }

          assert_includes error.message, "is not a tag name"
        end

        def test_a_void_element_with_content_teaches
          error = assert_raises(ArgumentError) do
            render_inline(Component.new(html_tag: "br")) { "dropped" }
          end

          assert_includes error.message, "void element"
        end
      end
    end
  end
end
