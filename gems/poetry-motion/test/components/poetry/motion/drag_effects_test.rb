# frozen_string_literal: true

require "test_helper"

module Poetry
  module Motion
    # The rank-seven drag effects render in place and wire their controllers.
    class DragEffectsTest < ViewComponent::TestCase
      def test_draggable_wires_its_axis_bounds_and_return
        render_inline(Draggable::Component.new(axis: :x, bounded: true, snap_back: false)) { "x" }
        root = page.find("[data-slot=draggable]")

        assert_equal "x", root["data-poetry--motion--draggable-axis-value"]
        assert_equal "true", root["data-poetry--motion--draggable-bounded-value"]
        assert_equal "false", root["data-poetry--motion--draggable-snap-back-value"]
        assert_raises(ArgumentError) { render_inline(Draggable::Component.new(axis: :z)) { "x" } }
      end

      def test_swipe_cards_render_a_focusable_labelled_stack
        render_inline(SwipeCards::Component.new(label: "Candidates", threshold: 80)) do |stack|
          stack.with_card(data: { id: 1 }) { "Ada" }
          stack.with_card { "Grace" }
          stack.with_empty { "Done" }
          stack.with_actions { "<button data-action=\"poetry--motion--swipe-cards#swipeLeft\">Skip</button>".html_safe }
        end
        root = page.find("[data-slot=swipe-cards]")

        assert_equal %w[group Candidates 0], [root[:role], root["aria-label"], root[:tabindex]]
        assert_equal "80", root["data-poetry--motion--swipe-cards-threshold-value"]
        cards = page.all("[data-slot=swipe-cards-card]")

        assert_equal %w[Ada Grace], cards.map(&:text)
        assert_equal "1", cards.first["data-id"]
        assert(cards.all? { |card| card["data-poetry--motion--swipe-cards-target"] == "card" })
        assert_selector "[data-slot=swipe-cards-empty]", text: "Done", visible: :all
        assert_selector "[data-slot=swipe-cards] > [data-slot=swipe-cards-actions] > button", text: "Skip"
        assert_selector "[data-slot=swipe-cards] > [data-slot=swipe-cards-deck] > [data-slot=swipe-cards-card]",
                        count: 2
      end

      def test_swipe_cards_need_a_label
        assert_raises(ArgumentError) { render_inline(SwipeCards::Component.new) { "x" } }
      end

      def test_the_helpers_render_each_effect
        view = ApplicationController.new.view_context

        assert_includes view.poetry_draggable { "x" }, "data-slot=\"draggable\""
        assert_includes view.poetry_swipe_cards(label: "Stack") { "" }, "data-slot=\"swipe-cards\""
      end
    end
  end
end
