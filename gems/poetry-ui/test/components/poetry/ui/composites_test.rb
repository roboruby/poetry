# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # N9 W4 native composites: Carousel (scroll-snap) + Resizable (APG
    # window splitter) - the render contracts; the engines are vitest'd in
    # poetry-core.
    class CompositesTest < ViewComponent::TestCase
      # -- Carousel -------------------------------------------------------------

      def render_carousel(**options)
        render_inline(Carousel::Component.new(label: "Artwork", **options)) do |carousel|
          3.times { |n| carousel.with_item { "slide #{n}" } }
        end
      end

      def test_carousel_is_a_named_region_of_slides_on_a_real_scroll_container
        html = render_carousel

        root = html.css('[data-slot="carousel"]').first

        assert_equal "region", root["role"]
        assert_equal "carousel", root["aria-roledescription"]
        assert_equal "Artwork", root["aria-label"]
        viewport = html.css('[data-slot="carousel-content"]').first

        assert_includes viewport["class"], "overflow-auto", "NATIVE scroll - no transform track"
        assert_includes viewport["class"], "snap-x"
        slides = html.css('[data-slot="carousel-item"]')

        assert_equal 3, slides.length
        slides.each do |slide|
          assert_equal "group", slide["role"]
          assert_equal "slide", slide["aria-roledescription"]
          assert_includes slide["class"], "snap-start"
        end
      end

      def test_carousel_controls_are_wired_accessible_buttons
        html = render_carousel

        previous = html.css('[data-slot="carousel-previous"]').first

        assert_equal "Previous slide", previous["aria-label"]
        assert_includes previous["data-action"], "poetry--core--carousel#previous"
        assert_includes html.css('[data-slot="carousel-next"]').first["data-action"],
                        "poetry--core--carousel#next"
        assert_empty render_carousel(show_controls: false).css('[data-slot="carousel-previous"]')
      end

      def test_carousel_requires_a_label_and_slides
        assert_raises(ArgumentError) do
          render_inline(Carousel::Component.new) { |c| c.with_item { "s" } }
        end
        assert_raises(ArgumentError) { render_inline(Carousel::Component.new(label: "A")) }
      end

      def test_carousel_item_classes_beat_the_dictionary_on_conflicts
        html = render_inline(Carousel::Component.new(label: "Strip")) do |carousel|
          carousel.with_item(classes: "basis-1/3") { "sized" }
          carousel.with_item { "default" }
        end

        sized, default = html.css('[data-slot="carousel-item"]')

        assert_includes sized["class"], "basis-1/3"
        refute_includes sized["class"], "basis-full",
                        "the caller's basis must WIN, not ride the cascade lottery"
        assert_includes default["class"], "basis-full"
      end

      # -- Resizable ------------------------------------------------------------

      def render_group(**options)
        render_inline(Resizable::Component.new(**options)) do |group|
          group.with_panel(default_size: 25, min_size: 15) { "sidebar" }
          group.with_panel { "content" }
        end
      end

      def test_resizable_panels_carry_their_sizes_as_flex_grow
        html = render_group

        panels = html.css('[data-slot="resizable-panel"]')

        assert_includes panels.first["style"], "flex: 25 1 0px"
        assert_equal "15", panels.first["data-min-size"]
        assert_includes panels.last["style"], "flex: 50.0 1 0px", "omitted sizes share evenly"
      end

      def test_the_handle_is_an_apg_window_splitter_between_the_panels
        html = render_group

        handle = html.css('[data-slot="resizable-handle"]').first

        assert_equal "separator", handle["role"]
        assert_equal "0", handle["tabindex"]
        assert_equal "vertical", handle["aria-orientation"], "a side-by-side group has a vertical bar"
        assert_equal html.css('[data-slot="resizable-panel"]').first["id"], handle["aria-controls"]
        %w[pointerdown->poetry--core--resizable#dragStart keydown->poetry--core--resizable#keydown].each do |action|
          assert_includes handle["data-action"], action
        end
      end

      def test_vertical_direction_flips_the_axis_tokens
        html = render_group(direction: :vertical, grip: true)

        root = html.css('[data-slot="resizable-panel-group"]').first

        assert_equal "vertical", root["data-orientation"]
        handle = html.css('[data-slot="resizable-handle"]').first

        assert_equal "horizontal", handle["aria-orientation"]
        assert_predicate html.css('[data-slot="resizable-handle"] div'), :any?, "grip: renders the pill"
      end

      def test_resizable_requires_two_panels
        assert_raises(ArgumentError) do
          render_inline(Resizable::Component.new) { |group| group.with_panel { "only" } }
        end
      end
    end
  end
end
