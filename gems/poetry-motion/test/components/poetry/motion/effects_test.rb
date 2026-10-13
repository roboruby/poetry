# frozen_string_literal: true

require "test_helper"

module Poetry
  module Motion
    # The four effects render their finished state on the server, wire
    # their controllers, and validate their options against the tokens.
    class EffectsTest < ViewComponent::TestCase
      def test_marquee_renders_one_readable_copy_and_inert_copies_with_a_pause_control
        render_inline(Marquee::Component.new(label: "Customers", repeat: 3)) { "<span>Acme</span>".html_safe }
        root = page.find("[data-slot=marquee]")

        assert_equal "region", root["role"]
        assert_equal "Customers", root["aria-label"]
        assert_equal "poetry--motion--marquee", root["data-controller"]
        assert_includes root["style"], "--marquee-duration: 40s"
        tracks = page.all("[data-slot=marquee-track]", visible: :all)

        assert_equal 3, tracks.size
        assert_nil tracks.first["aria-hidden"]
        assert(tracks.drop(1).all? { |track| track["aria-hidden"] == "true" && track[:inert] })
        pause = page.find("button[data-slot=marquee-pause]")

        assert_equal "false", pause["aria-pressed"]
        assert_equal "click->poetry--motion--marquee#toggle", pause["data-action"]
        assert_equal "pause", pause["data-poetry--motion--marquee-target"]
      end

      def test_marquee_without_pause_or_motion
        render_inline(Marquee::Component.new(pausable: false, animate: false)) { "x" }

        assert_no_selector "[data-slot=marquee-pause]"
        assert_selector "[data-slot=marquee][data-animate=false]"
      end

      def test_marquee_validates_its_options
        assert_raises(ActiveModel::ValidationError, ArgumentError) do
          render_inline(Marquee::Component.new(direction: :sideways)) { "x" }
        end
        assert_raises(ActiveModel::ValidationError, ArgumentError) do
          render_inline(Marquee::Component.new(repeat: 1)) { "x" }
        end
      end

      def test_text_reveal_renders_the_text_for_readers_and_hidden_words
        render_inline(TextReveal::Component.new("Every word arrives", tag: :h2))
        root = page.find("h2[data-slot=text-reveal]")

        assert_includes root["style"], "--reveal-count: 3"
        assert_equal "poetry--motion--text-reveal", root["data-controller"]
        assert_selector "h2 > span.sr-only", text: "Every word arrives", visible: :all
        words = page.all("[aria-hidden=true] [data-slot=text-reveal-word]", visible: :all)

        assert_equal %w[Every word arrives], words.map(&:text)
        assert_equal "--word-index: 2", words.last["style"]
      end

      def test_text_reveal_without_motion_wires_nothing
        render_inline(TextReveal::Component.new("Still", animate: false))

        assert_nil page.find("[data-slot=text-reveal]")["data-controller"]
      end

      def test_number_ticker_renders_the_final_number_twice_and_its_count_values
        render_inline(NumberTicker::Component.new(value: 12_480, from: 100, delay: 200))
        root = page.find("[data-slot=number-ticker]")

        assert_selector ".sr-only", text: "12,480", visible: :all
        display = page.find("[data-slot=number-ticker-display]", visible: :all)

        assert_equal "12,480", display.text
        assert_equal "true", display["aria-hidden"]
        assert_equal "display", display["data-poetry--motion--number-ticker-target"]
        assert_equal "12480.0", root["data-poetry--motion--number-ticker-value-value"]
        assert_equal "100.0", root["data-poetry--motion--number-ticker-from-value"]
        assert_equal "gentle", root["data-poetry--motion--number-ticker-spring-value"]
        assert_equal "in_view", root["data-poetry--motion--number-ticker-trigger-value"]
        assert_equal "200", root["data-poetry--motion--number-ticker-delay-value"]
        assert_nil root["data-poetry--motion--number-ticker-animate-value"]
      end

      def test_number_ticker_formats_currency_and_percent_on_the_server
        render_inline(NumberTicker::Component.new(value: 48_250.5,
                                                  format: { style: "currency", currency: "USD",
                                                            minimumFractionDigits: 2 }))

        assert_equal "$48,250.50", page.find("[data-slot=number-ticker-display]", visible: :all).text
        assert_includes page.find("[data-slot=number-ticker]")["data-poetry--motion--number-ticker-format-value"],
                        "\"currency\":\"USD\""

        render_inline(NumberTicker::Component.new(value: 0.982, format: { style: "percent", maximumFractionDigits: 1 }))

        assert_equal "98.2%", page.find("[data-slot=number-ticker-display]", visible: :all).text
      end

      def test_number_ticker_rejects_tokens_it_does_not_know
        assert_raises(ActiveModel::ValidationError, ArgumentError) do
          render_inline(NumberTicker::Component.new(value: 1, spring: :limp))
        end
        assert_raises(ActiveModel::ValidationError, ArgumentError) do
          render_inline(NumberTicker::Component.new(value: 1, trigger: :hover))
        end
      end

      def test_tilt_card_renders_flat_with_a_layer_that_leans
        render_inline(TiltCard::Component.new(max: 12)) { "<p>Card</p>".html_safe }
        root = page.find("[data-slot=tilt-card]")

        assert_equal "poetry--motion--tilt-card", root["data-controller"]
        assert_equal "12", root["data-poetry--motion--tilt-card-max-value"]
        layer = root.find("[data-slot=tilt-card-layer]")

        assert_equal "layer", layer["data-poetry--motion--tilt-card-target"]
        assert_nil layer["style"]
        assert_selector "[data-slot=tilt-card-layer] > p", text: "Card"
      end

      def test_the_effects_list_their_motion_behaviors
        assert_equal(%w[animate spring], NumberTicker::Component.behavior_definitions.map { |b| b["name"] })
        assert_equal(%w[pointer spring], TiltCard::Component.behavior_definitions.map { |b| b["name"] })
        assert_equal(%w[scroll_value], TextReveal::Component.behavior_definitions.map { |b| b["name"] })
        assert_match(/decoration/, NumberTicker::Component.agent_rules.first)
      end

      def test_the_helpers_render_each_effect
        view = ApplicationController.new.view_context

        assert_includes view.poetry_marquee { "x" }, "data-slot=\"marquee\""
        assert_includes view.poetry_text_reveal("Hi"), "data-slot=\"text-reveal\""
        assert_includes view.poetry_number_ticker(value: 3), "data-slot=\"number-ticker\""
        assert_includes view.poetry_tilt_card { "x" }, "data-slot=\"tilt-card\""
      end
    end
  end
end
