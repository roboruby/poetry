# frozen_string_literal: true

require "test_helper"

module Poetry
  module Motion
    # The rank-one layout effects render their finished state and wire
    # their controllers only when they animate.
    class LayoutEffectsTest < ViewComponent::TestCase
      def test_animated_list_renders_the_items_under_its_own_key
        render_inline(AnimatedList::Component.new(as: :ol, id: "feed")) { "<li>one</li>".html_safe }
        list = page.find("ol[data-slot=animated-list]")

        assert_equal "feed", list[:id]
        assert_equal "feed", list["data-animated-list"], "the caller's id keys the list"
        assert_equal "poetry--motion--animated-list", list["data-controller"]
        assert_equal "300", list["data-poetry--motion--animated-list-duration-value"]
        assert_selector "ol > li", text: "one"
      end

      def test_animated_list_takes_milliseconds_and_turns_off
        render_inline(AnimatedList::Component.new(duration: 450)) { "<li>x</li>".html_safe }

        assert_equal "450", page.find("ul")["data-poetry--motion--animated-list-duration-value"]

        render_inline(AnimatedList::Component.new(animate: false)) { "<li>x</li>".html_safe }

        assert_nil page.find("ul")["data-controller"]
        assert_raises(ArgumentError) { render_inline(AnimatedList::Component.new(duration: :glacial)) { "x" } }
      end

      def test_layout_group_wires_its_controller
        render_inline(LayoutGroup::Component.new(duration: :fast)) { "<span data-layout-id=\"pill\"></span>".html_safe }
        group = page.find("[data-slot=layout-group]")

        assert_equal "poetry--motion--layout-group", group["data-controller"]
        assert_equal "150", group["data-poetry--motion--layout-group-duration-value"]
      end

      def test_shared_element_names_its_view_transition
        render_inline(SharedElement::Component.new(name: "product-42", as: :article)) { "card" }

        assert_equal "view-transition-name: product-42", page.find("article[data-slot=shared-element]")["style"]
        assert_raises(ArgumentError) { render_inline(SharedElement::Component.new(name: "has space")) { "x" } }
      end

      def test_the_helpers_render_each_effect
        view = ApplicationController.new.view_context

        assert_includes view.poetry_animated_list { "x" }, "data-slot=\"animated-list\""
        assert_includes view.poetry_layout_group { "x" }, "data-slot=\"layout-group\""
        assert_includes view.poetry_shared_element(name: "hero") { "x" }, "view-transition-name: hero"
      end
    end
  end
end
