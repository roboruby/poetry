# frozen_string_literal: true

require "test_helper"

module Poetry
  module Motion
    # The CSS-only background: an aria-hidden layer behind the content,
    # deterministic particles, and no controller at all.
    class BackgroundTest < ViewComponent::TestCase
      def test_a_pattern_and_an_effect_behind_the_content_with_no_script
        render_inline(Background::Component.new(pattern: :dots, effect: :meteors, count: 3)) { "<h2>Hi</h2>".html_safe }
        root = page.find("[data-slot=background]")

        assert_equal %w[dots meteors radial], [root["data-pattern"], root["data-effect"], root["data-fade"]]
        assert_nil root["data-controller"]
        layer = page.find("[data-slot=background-layer]", visible: :all)

        assert_equal "true", layer["aria-hidden"]
        particles = page.all("[data-slot=background-particle]", visible: :all)

        assert_equal 3, particles.size
        assert_includes particles[1]["style"], "--particle-x: 48%"
        assert_selector "h2", text: "Hi"
      end

      def test_renders_the_same_every_time
        html = -> { render_inline(Background::Component.new(effect: :ripple, count: 4)).to_html }

        assert_equal html.call, html.call
      end

      def test_patterns_without_particles_and_bad_values
        render_inline(Background::Component.new(effect: :aurora, animate: false))

        assert_no_selector "[data-slot=background-particle]", visible: :all
        assert_selector "[data-slot=background][data-animate=false]"
        assert_raises(ArgumentError) { render_inline(Background::Component.new(effect: :lasers)) }
        assert_raises(ArgumentError) { render_inline(Background::Component.new(count: 99)) }
        assert_includes ApplicationController.new.view_context.poetry_background { "x" }, "data-slot=\"background\""
      end
    end
  end
end
