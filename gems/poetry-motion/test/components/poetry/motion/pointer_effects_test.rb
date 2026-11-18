# frozen_string_literal: true

require "test_helper"

module Poetry
  module Motion
    # The rank-two pointer effects render at rest and wire their
    # controllers only when they animate.
    class PointerEffectsTest < ViewComponent::TestCase
      def test_spotlight_card_renders_without_a_glow
        render_inline(SpotlightCard::Component.new(size: 400)) { "<p>Card</p>".html_safe }
        card = page.find("[data-slot=spotlight-card]")

        assert_equal "poetry--motion--spotlight-card", card["data-controller"]
        assert_equal "--spotlight-size: 400px", card["style"]
        assert_raises(ArgumentError) { render_inline(SpotlightCard::Component.new(size: 4)) { "x" } }
      end

      def test_magnetic_moves_a_layer_and_never_its_wrapper
        render_inline(Magnetic::Component.new(strength: 12)) { "<button>Go</button>".html_safe }
        wrapper = page.find("[data-slot=magnetic]")

        assert_equal "12", wrapper["data-poetry--motion--magnetic-strength-value"]
        assert_equal "layer", wrapper.find("[data-slot=magnetic-layer]")["data-poetry--motion--magnetic-target"]
        assert_selector "[data-slot=magnetic-layer] > button", text: "Go"

        render_inline(Magnetic::Component.new(animate: false)) { "<button>Go</button>".html_safe }

        assert_nil page.find("[data-slot=magnetic]")["data-controller"]
        assert_nil page.find("[data-slot=magnetic-layer]")["data-poetry--motion--magnetic-target"]
      end

      def test_dock_is_a_named_navigation
        render_inline(Dock::Component.new(label: "Apps", orientation: :vertical, magnification: 2.0)) do
          "<a href=\"#\" aria-label=\"Mail\">M</a>".html_safe
        end
        dock = page.find("nav[data-slot=dock]")

        assert_equal "Apps", dock["aria-label"]
        assert_equal "vertical", dock["data-orientation"]
        assert_equal "2.0", dock["data-poetry--motion--dock-magnification-value"]
        assert_raises(ArgumentError) { render_inline(Dock::Component.new(magnification: 9.0)) { "x" } }
        assert_raises(ArgumentError) { render_inline(Dock::Component.new(orientation: :diagonal)) { "x" } }
      end

      def test_the_helpers_render_each_effect
        view = ApplicationController.new.view_context

        assert_includes view.poetry_spotlight_card { "x" }, "data-slot=\"spotlight-card\""
        assert_includes view.poetry_magnetic { "x" }, "data-slot=\"magnetic\""
        assert_includes view.poetry_dock { "x" }, "data-slot=\"dock\""
      end
    end
  end
end
