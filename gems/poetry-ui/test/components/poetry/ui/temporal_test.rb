# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # N9 W6 temporal pair: Calendar (server-rendered own-the-engine grid) +
    # DatePicker (Popover + Calendar composition). The render contracts; the
    # engines are vitest'd in poetry-core.
    class TemporalTest < ViewComponent::TestCase
      # -- Calendar -------------------------------------------------------------

      def render_calendar(**)
        render_inline(Calendar::Component.new(month: "2026-06-01", today: "2026-06-15", **))
      end

      def test_the_calendar_server_renders_a_full_month_grid
        html = render_calendar(selected: "2026-06-12")

        days = html.css('[data-slot="calendar-day"]')

        assert_equal 42, days.length, "6 weeks, always - stable layout"
        assert_equal %w[Su Mo Tu We Th Fr Sa], html.css('[data-slot="calendar-weekday"]').map(&:text)
        assert_equal "June 2026", html.css('[data-slot="calendar-caption"]').first.text
      end

      def test_the_selected_and_today_days_wear_the_vocabulary
        html = render_calendar(selected: "2026-06-12")

        selected = html.css("[data-selected]")

        assert_equal 1, selected.length
        assert_equal "2026-06-12", selected.first["data-date"]
        # aria-selected rides the role=gridcell parent (the ARIA grid contract).
        assert_equal "true", selected.first.parent["aria-selected"]
        assert_equal "gridcell", selected.first.parent["role"]
        today = html.css("[data-today]").first

        assert_equal "2026-06-15", today["data-date"]
        assert_equal "date", today["aria-current"]
      end

      def test_outside_days_are_marked_and_the_grid_is_wired
        html = render_calendar

        # June 1 2026 is a Monday, so the grid leads with May 31 (Sunday).
        first = html.css('[data-slot="calendar-day"]').first

        assert_equal "2026-05-31", first["data-date"]
        assert first.key?("data-outside")
        assert_includes first["data-action"], "click->poetry--core--calendar#select"
        root = html.css('[data-slot="calendar"]').first

        assert_includes root["data-controller"], "poetry--core--calendar"
        assert_equal "2026-06", root["data-poetry--core--calendar-month-value"]
      end

      def test_min_max_disable_out_of_range_days_server_side
        html = render_calendar(min: "2026-06-10", max: "2026-06-20")

        day = ->(iso) { html.css(%([data-date="#{iso}"])).first }

        assert day.call("2026-06-05")["disabled"], "before min is disabled with no JS"
        assert_nil day.call("2026-06-15")["disabled"]
        assert day.call("2026-06-25")["disabled"]
      end

      def test_name_makes_it_a_form_control
        html = render_calendar(selected: "2026-06-12", name: "due_on")

        input = html.css('input[type="hidden"][name="due_on"]').first

        assert_equal "2026-06-12", input["value"]
        assert_equal "input", input["data-poetry--core--calendar-target"], "the controller writes it on select"
      end

      def test_exactly_one_day_is_the_tab_stop
        html = render_calendar(selected: "2026-06-12")

        stops = html.css('[data-slot="calendar-day"][tabindex="0"]')

        assert_equal 1, stops.length
        assert_equal "2026-06-12", stops.first["data-date"], "the selection is the tab stop"
      end

      # -- DatePicker -----------------------------------------------------------

      def test_the_date_picker_is_a_popover_wrapping_a_calendar
        html = render_inline(DatePicker::Component.new(name: "due_on", label: "Due date"))

        root = html.css('[data-slot="date-picker"]').first

        assert_includes root["data-controller"], "poetry--core--date-picker"
        assert_includes root["data-action"], "poetry--core--calendar:change->poetry--core--date-picker#picked"
        assert_predicate html.css('[data-slot="popover-trigger"]'), :any?, "the field is a popover trigger"
        assert_predicate html.css('[data-slot="calendar"]'), :any?, "the panel is a Calendar"
        assert_predicate html.css('input[name="due_on"]'), :any?, "the Calendar carries the form field"
      end

      def test_a_preselected_date_shows_formatted_with_no_js
        html = render_inline(DatePicker::Component.new(name: "due_on", value: "2026-06-12"))

        label = html.css('[data-poetry--core--date-picker-target="label"]').first

        assert_equal "June 12, 2026", label.text.strip
        assert_equal "2026-06-12", html.css("[data-selected]").first["data-date"]
      end

      def test_an_empty_date_picker_shows_the_placeholder
        html = render_inline(DatePicker::Component.new(name: "due_on"))

        label = html.css('[data-poetry--core--date-picker-target="label"]').first

        assert_equal "Pick a date", label.text.strip
      end

      def test_the_date_picker_requires_a_name
        error = assert_raises(ArgumentError) { render_inline(DatePicker::Component.new) }

        assert_match(/requires name:/, error.message)
      end
    end
  end
end
