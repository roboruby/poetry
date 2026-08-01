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

      # -- Calendar range mode (N9 D1) ---------------------------------------

      def test_a_preselected_range_paints_the_span_with_no_js
        html = render_calendar(mode: :range, selected: Date.new(2026, 6, 9)..Date.new(2026, 6, 12))
        day = ->(iso) { html.css(%([data-date="#{iso}"])).first }

        assert day.call("2026-06-09").key?("data-range-start")
        assert day.call("2026-06-10").key?("data-range-middle")
        assert day.call("2026-06-11").key?("data-range-middle")
        assert day.call("2026-06-12").key?("data-range-end")
        refute day.call("2026-06-09").key?("data-selected"), "complete ranges wear only the range vocabulary"

        # aria-selected marks the whole span on the gridcells.
        span_cells = %w[2026-06-09 2026-06-10 2026-06-12].map do |iso|
          day.call(iso).parent["aria-selected"]
        end

        assert_equal %w[true true true], span_cells
        assert_equal "false", day.call("2026-06-13").parent["aria-selected"]
      end

      def test_a_start_only_range_renders_as_a_selected_single_day
        html = render_calendar(mode: :range, selected: [Date.new(2026, 6, 9), nil])
        day = html.css('[data-date="2026-06-09"]').first

        assert day.key?("data-selected"), "rdp semantics: incomplete picks look single"
        refute day.key?("data-range-start")
      end

      def test_range_mode_posts_two_nested_inputs
        html = render_calendar(mode: :range, name: "stay",
                               selected: { start: "2026-06-09", end: "2026-06-12" })

        assert_equal "2026-06-09", html.css('input[name="stay[start]"]').first["value"]
        assert_equal "2026-06-12", html.css('input[name="stay[end]"]').first["value"]
        assert_empty html.css('input[name="stay"]'), "the single-mode input is replaced"
      end

      def test_range_mode_wires_the_controller_values
        html = render_calendar(mode: :range, selected: %w[2026-06-09 2026-06-12])
        root = html.css('[data-slot="calendar"]').first

        assert_equal "range", root["data-poetry--core--calendar-mode-value"]
        assert_equal "2026-06-09", root["data-poetry--core--calendar-range-start-value"]
        assert_equal "2026-06-12", root["data-poetry--core--calendar-range-end-value"]
      end

      def test_unknown_calendar_mode_teaches
        error = assert_raises(ArgumentError) { render_calendar(mode: :multi) }

        assert_match(/unknown mode/, error.message)
      end

      def test_calendar_week_numbers_render_iso_rowheaders
        html = render_calendar(week_numbers: true)

        rows = html.css('[role="rowheader"][data-slot="calendar-week-number"]')

        # June 2026 shows ISO weeks 23-28 (each row's Thursday decides).
        assert_equal(%w[23 24 25 26 27 28], rows.map { |cell| cell.text.strip })
        assert_equal 1, html.css('[role="columnheader"][data-slot="calendar-week-number"]').length,
                     "the header row gains the week column stub"
      end

      def test_calendar_dropdown_caption_renders_the_overlay_select_pair
        html = render_calendar(caption_layout: :dropdown, min: "2025-01-01", max: "2027-12-31")

        units = html.css("[data-calendar-unit]")

        assert_equal(%w[month year], units.map { |unit| unit["data-calendar-unit"] })
        assert_equal "June", html.css('[data-calendar-unit="month"] option[selected]').first.text
        assert_equal %w[2025 2026 2027], html.css('[data-calendar-unit="year"] option').map { |o| o["value"] },
                     "min/max pin the year list"
        assert_empty html.css('[data-poetry--core--calendar-target="caption"]'),
                     "dropdown mode replaces the text caption target"

        # The overlay pattern: visible text label (aria-hidden - the select
        # carries the value), the real select invisible on top.
        month = html.css('[data-calendar-unit="month"]').first

        assert_equal "June", month.css('[data-slot="calendar-dropdown-value"]').first.text
        assert_equal "true", month.css('[data-slot="calendar-caption-label"]').first["aria-hidden"]
        assert_includes month.css("select").first["class"], "opacity-0"
        assert_equal "Month", month.css("select").first["aria-label"]
      end

      def test_unknown_caption_layout_teaches
        error = assert_raises(ArgumentError) { render_calendar(caption_layout: :fancy) }

        assert_match(/unknown caption_layout/, error.message)
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

      def test_a_range_date_picker_joins_the_label_and_passes_the_mode_down
        html = render_inline(DatePicker::Component.new(name: "stay", mode: :range, label: "Stay",
                                                       value: %w[2026-06-09 2026-06-18],
                                                       month: "2026-06-01"))

        label = html.css('[data-poetry--core--date-picker-target="label"]').first

        # SHORT month names for ranges (upstream's LLL dd convention) - two
        # long-month dates outgrow the trigger; the trigger also runs wider.
        assert_equal "Jun 9, 2026 – Jun 18, 2026", label.text.strip
        assert_includes html.css('[data-slot="date-picker"] button').first["class"].split, "w-72"
        assert_equal "range",
                     html.css('[data-slot="date-picker"]').first["data-poetry--core--date-picker-mode-value"]
        assert_equal "2026-06-09", html.css('input[name="stay[start]"]').first["value"]
        assert html.css('[data-date="2026-06-12"]').first.key?("data-range-middle"),
               "the wrapped calendar paints the span server-side"
      end

      def test_the_input_variant_renders_an_input_group_with_the_picker_wiring
        html = render_inline(DatePicker::Component.new(name: "sub_on", variant: :input,
                                                       label: "Subscription date",
                                                       value: "2026-06-01", month: "2026-06-01"))

        input = html.css('input[data-poetry--core--date-picker-target="input"]').first

        assert input, "the visible text input is the picker's input target"
        assert_equal "June 1, 2026", input["value"]
        assert_nil input["name"], "the visible input never carries the form name"
        assert_includes input["data-action"], "input->poetry--core--date-picker#inputChanged"
        assert_includes input["data-action"], "keydown->poetry--core--date-picker#inputKeydown"
        # The calendar's hidden ISO input stays THE form value.
        assert_equal "2026-06-01", html.css('input[type="hidden"][name="sub_on"]').first["value"]
        assert html.css('[data-slot="input-group"]').first, "wrapped in an InputGroup"
      end

      def test_the_input_variant_is_single_mode_only
        error = assert_raises(ArgumentError) do
          render_inline(DatePicker::Component.new(name: "stay", variant: :input, mode: :range))
        end

        assert_match(/single-mode/, error.message)
      end

      def test_the_date_picker_requires_a_name
        error = assert_raises(ArgumentError) { render_inline(DatePicker::Component.new) }

        assert_match(/requires name:/, error.message)
      end
    end
  end
end
