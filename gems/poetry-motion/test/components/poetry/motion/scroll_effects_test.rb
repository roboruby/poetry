# frozen_string_literal: true

require "test_helper"

module Poetry
  module Motion
    # The rank-five scroll effects render at rest and wire their controllers.
    class ScrollEffectsTest < ViewComponent::TestCase
      def test_scroll_progress_is_an_empty_decorative_bar
        render_inline(ScrollProgress::Component.new(target: "article", position: :bottom))
        bar = page.find("[data-slot=scroll-progress]", visible: :all)

        assert_equal "true", bar["aria-hidden"]
        assert_equal "bottom", bar["data-position"]
        assert_equal "article", bar["data-poetry--motion--scroll-progress-target-id-value"]
        assert_raises(ArgumentError) { render_inline(ScrollProgress::Component.new(position: :side)) }
      end

      def test_parallax_wraps_its_content_at_rest
        render_inline(Parallax::Component.new(distance: -60)) { "<img alt=\"\">".html_safe }
        root = page.find("[data-slot=parallax]")

        assert_equal "-60", root["data-poetry--motion--parallax-distance-value"]
        assert_nil root["style"]
        assert_raises(ArgumentError) { render_inline(Parallax::Component.new(distance: 900)) { "x" } }

        render_inline(Parallax::Component.new(animate: false)) { "x" }

        assert_nil page.find("[data-slot=parallax]")["data-controller"]
      end

      def test_the_helpers_render_each_effect
        view = ApplicationController.new.view_context

        assert_includes view.poetry_scroll_progress, "data-slot=\"scroll-progress\""
        assert_includes view.poetry_parallax { "x" }, "data-slot=\"parallax\""
      end
    end
  end
end
