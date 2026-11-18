# frozen_string_literal: true

require "test_helper"

module Poetry
  module Motion
    # The rank-six canvas effects render their canvas on the server and
    # wire their controllers.
    class CanvasEffectsTest < ViewComponent::TestCase
      def test_particles_put_an_aria_hidden_canvas_behind_the_content
        render_inline(Particles::Component.new(count: 40, link: 80)) { "<h2>Hi</h2>".html_safe }
        root = page.find("[data-slot=particles]")

        assert_equal "80", root["data-poetry--motion--particles-link-value"]
        canvas = page.find("canvas[data-slot=particles-canvas]", visible: :all)

        assert_equal "true", canvas["aria-hidden"]
        assert_equal "canvas", canvas["data-poetry--motion--particles-target"]
        assert_raises(ArgumentError) { render_inline(Particles::Component.new(count: 0)) }
      end

      def test_confetti_wraps_its_control_with_a_viewport_canvas
        render_inline(Confetti::Component.new(count: 200)) { "<button>Ship</button>".html_safe }
        root = page.find("[data-slot=confetti]")

        assert_equal "click", root["data-poetry--motion--confetti-trigger-value"]
        assert_selector "[data-slot=confetti] > button", text: "Ship"
        canvas = page.find("canvas[data-slot=confetti-canvas]", visible: :all)

        assert_includes canvas[:class], "pointer-events-none"
        assert_raises(ArgumentError) { render_inline(Confetti::Component.new(trigger: :hover)) { "x" } }
      end

      def test_globe_carries_its_markers_and_a_label
        render_inline(Globe::Component.new(markers: [[37.77, -122.42]], label: "Offices"))
        root = page.find("[data-slot=globe]")

        assert_equal "[[37.77,-122.42]]", root["data-poetry--motion--globe-markers-value"]
        canvas = page.find("canvas[data-slot=globe-canvas]", visible: :all)

        assert_equal %w[img Offices], [canvas[:role], canvas["aria-label"]]
        assert_raises(ArgumentError) { render_inline(Globe::Component.new(markers: [[1]])) }
      end

      def test_the_helpers_render_each_effect
        view = ApplicationController.new.view_context

        assert_includes view.poetry_particles, "data-slot=\"particles\""
        assert_includes view.poetry_confetti { "x" }, "data-slot=\"confetti\""
        assert_includes view.poetry_globe, "data-slot=\"globe\""
      end
    end
  end
end
