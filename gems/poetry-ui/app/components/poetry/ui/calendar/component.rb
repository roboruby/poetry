# frozen_string_literal: true

require "date"

module Poetry
  module Ui
    module Calendar
      # The Calendar - a server-rendered month grid (Ruby Date math) driven
      # by poetry--core--calendar. The W6 own-the-engine decision: no
      # react-day-picker; the initial month renders correctly with no JS,
      # and the controller handles navigation + selection on top. Selection
      # is a real form value (name: -> a hidden input); a bare Calendar
      # picks a date, the DatePicker wraps it in a Popover.
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "name: makes it a form control (the chosen date posts as an ISO string in a hidden input; " \
          "range mode posts name[start] + name[end]).",
          "month:/selected:/today accept a Date or an ISO string; min:/max: bound the selectable range.",
          "mode: :range selects a span - selected: takes a Date..Date Range, [start, end], or " \
          "{start:, end:}; the second click completes, click-before-start swaps, re-click clears.",
          "The grid is server-rendered - it shows a valid month with no JS; the controller adds " \
          "navigation + selection.",
          "For a text-field + popover, use DatePicker (it composes this) - a bare Calendar is the " \
          "always-visible grid.",
          "caption_layout: :dropdown swaps the month label for month + year selects (jump " \
          "navigation); the year list derives from min:/max: when both are set, else ten years " \
          "around the initial month.",
          "week_numbers: true adds the ISO week column (each row's Thursday decides the number)."
        ].freeze

        CONTROLLER = %i[poetry core calendar].freeze
        MODES = %i[single range].freeze
        CAPTION_LAYOUTS = %i[label dropdown].freeze

        option :name, :string
        option :mode, :symbol, default: :single
        option :week_start, :integer, default: 0 # 0 = Sunday
        option :caption_layout, :symbol, default: :label
        option :week_numbers, :boolean, default: false

        part "calendar", "Root wrapper - the calendar controller (navigation, selection, roving " \
                         "arrow keys) rides here"
        part "calendar-nav", "The header row - previous/next month Buttons around the caption"
        part "calendar-caption", "The month label ('July 2026') - the controller rewrites it on " \
                                 "navigation from the localized month names; under " \
                                 "caption_layout: :dropdown it holds the month/year NativeSelect " \
                                 "pair instead (the controller reflects navigation into them)"
        part "calendar-week-number", "The ISO week column (week_numbers:) - a columnheader stub " \
                                     "plus one muted rowheader number per week; non-interactive"
        part "calendar-grid", "The role=grid - the weekday header row plus six week rows " \
                              "(42 cells, always full weeks)"
        part "calendar-weekdays", "The role=row of weekday column headers"
        part "calendar-weekday", "One role=columnheader two-letter day label"
        part "calendar-week", "One role=row of seven day cells"
        part "calendar-day-cell", "The role=gridcell wrapper - aria-selected lives HERE (the " \
                                  "ARIA grid contract; it is not valid on the button)"
        part "calendar-day", "One day <button> - the selection vocabulary and the roving tab " \
                             "stop ride here",
             states: {
               "data-date" => "always - the day's ISO date (the controller's selection key)",
               "data-selected" => "the day is the single-mode pick, or a start-only range pick " \
                                  "(bare; a complete range wears the range-* trio instead)",
               "data-range-start" => "the day starts a COMPLETE range",
               "data-range-end" => "the day ends a COMPLETE range",
               "data-range-middle" => "the day sits strictly inside a complete range",
               "data-today" => "the day is today (aria-current=date rides along)",
               "data-outside" => "the day belongs to a neighbouring month (leading/trailing fill)"
             }
        part "calendar-day-label", "The day-number span inside the button"

        def initialize(month: nil, selected: nil, min: nil, max: nil, today: nil, **) # rubocop:disable Metrics/ParameterLists
          super(**)
          raise ArgumentError, "unknown mode #{mode.inspect} (one of #{MODES.join(", ")})" unless MODES.include?(mode)
          unless CAPTION_LAYOUTS.include?(caption_layout)
            raise ArgumentError, "unknown caption_layout #{caption_layout.inspect} " \
                                 "(one of #{CAPTION_LAYOUTS.join(", ")})"
          end

          if range?
            @range_start, @range_end = parse_range(selected)
          else
            @selected = to_date(selected)
          end
          @today = to_date(today) || Date.today
          @min = to_date(min)
          @max = to_date(max)
          @month = to_date(month) || @selected || @range_start || @today
        end

        attr_reader :selected, :today, :min, :max, :range_start, :range_end

        def range? = mode == :range
        def range_complete? = !!(@range_start && @range_end)

        def in_span?(date)
          return false unless range?
          return date == @range_start unless range_complete?

          date.between?(@range_start, @range_end)
        end

        # The 42 cells (6 weeks) for the visible month, leading/trailing
        # days from the neighbours so every week is full.
        def cells
          first = Date.new(@month.year, @month.month, 1)
          lead = (first.wday - week_start) % 7
          start = first - lead
          (0...42).map { |offset| start + offset }
        end

        def weekday_labels
          Date::ABBR_DAYNAMES.rotate(week_start).map { |name| name[0, 2] }
        end

        def in_month?(date) = date.month == @month.month
        def selected?(date) = @selected && date == @selected
        def today?(date) = date == @today
        def disabled?(date) = (@min && date < @min) || (@max && date > @max)

        def caption
          @month.strftime("%B %Y")
        end

        def dropdown_caption? = caption_layout == :dropdown

        def month_options
          Date::MONTHNAMES.compact.each_with_index.map { |label, index| [label, index + 1] }
        end

        # min:/max: pin the year list when both are given; otherwise ten
        # years either side of the initial month (the demo-friendly default;
        # bound it deliberately via min:/max: in real pickers).
        def year_options
          years = @min && @max ? (@min.year..@max.year) : ((@month.year - 10)..(@month.year + 10))
          years.map { |year| [year.to_s, year] }
        end

        # The ISO week of a displayed row: its Thursday decides (ISO 8601),
        # which stays correct under any week_start.
        def iso_week(week)
          week.find { |date| date.cwday == 4 }.cweek
        end

        # Exactly one day is the tab stop: the selection (the range start
        # in range mode), else today (in view), else the first enabled day.
        def tab_stop
          anchor = range? ? @range_start : @selected
          @tab_stop ||= (anchor if anchor && in_month?(anchor)) ||
                        (@today if in_month?(@today)) ||
                        cells.find { |date| in_month?(date) && !disabled?(date) }
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "calendar", "class" => css }.merge(root_stimulus_attributes)
                                                          .merge(component_data_attributes)
          )
        end

        # aria-selected lives on the role=gridcell (the ARIA grid contract -
        # it is not a valid attribute on a plain button, the axe catch).
        # Range mode marks the whole span.
        def cell_attributes(date)
          selected = range? ? in_span?(date) : selected?(date)
          {
            "role" => "gridcell", "data-slot" => "calendar-day-cell",
            "class" => css(:day_cell), "aria-selected" => selected.to_s
          }
        end

        def day_attributes(date)
          iso = date.iso8601
          attrs = {
            "type" => "button", "data-slot" => "calendar-day",
            "data-date" => iso, "class" => css(:day),
            "aria-label" => date.strftime("%B %-d, %Y"),
            "tabindex" => date == tab_stop ? "0" : "-1"
          }.merge(day_stimulus_attributes)
          merge_selection_attributes(attrs, date)
          attrs["data-today"] = "" if today?(date)
          attrs["data-outside"] = "" unless in_month?(date)
          attrs["aria-current"] = "date" if today?(date)
          if disabled?(date)
            attrs["disabled"] = true
            attrs["aria-disabled"] = "true"
          end
          attrs
        end

        def previous_options
          nav_options("Previous month", :previousMonth)
        end

        def next_options
          nav_options("Next month", :nextMonth)
        end

        private

        # The action method is the camelCase JS name (validated against the
        # controllers manifest by the action-contract test).
        def nav_options(label, method)
          {
            variant: :ghost, size: :icon, label: label, class: css(:nav_button),
            data: { action: "click->poetry--core--calendar##{method}" }
          }
        end

        def to_date(value)
          return if value.nil?
          return value if value.is_a?(Date)

          Date.parse(value.to_s)
        end

        # A preselected range: Date..Date, [start, end], or {start:, end:}.
        def parse_range(value)
          case value
          when nil then [nil, nil]
          when Range then [to_date(value.first), to_date(value.last)]
          when Array then [to_date(value[0]), to_date(value[1])]
          when Hash
            pair = value.symbolize_keys
            [to_date(pair[:start]), to_date(pair[:end])]
          else
            [to_date(value), nil] # a single value starts the range
          end
        end

        # The selection vocabulary per day (rdp semantics): a COMPLETE
        # range wears range-start/middle/end; a start-only pick is a plain
        # selected single day; single mode keeps data-selected.
        def merge_selection_attributes(attrs, date)
          if range?
            if range_complete?
              attrs["data-range-start"] = "" if date == @range_start
              attrs["data-range-end"] = "" if date == @range_end
              attrs["data-range-middle"] = "" if date > @range_start && date < @range_end
            elsif @range_start && date == @range_start
              attrs["data-selected"] = ""
            end
          elsif selected?(date)
            attrs["data-selected"] = ""
          end
        end

        def root_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          calendar = Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          calendar.register_controller
          calendar.with_value(:month, @month.strftime("%Y-%m"))
          calendar.with_value(:selected, @selected&.iso8601 || "")
          if range?
            calendar.with_value(:mode, "range")
            calendar.with_value(:range_start, @range_start&.iso8601 || "")
            calendar.with_value(:range_end, @range_end&.iso8601 || "")
          end
          calendar.with_value(:week_start, week_start)
          calendar.with_value(:min, @min&.iso8601 || "")
          calendar.with_value(:max, @max&.iso8601 || "")
          # Hand the controller the localized month names (I18n), so JS
          # month navigation needs no Intl - the caption stays app-locale
          # correct and works in the Intl-less dommy engine.
          calendar.with_value(:month_names, I18n.t("date.month_names").drop(1))
          attrs.to_attributes
        end

        def day_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          calendar = Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          calendar.with_target(:day)
          calendar.with_action(:select, on: :click)
          attrs.to_attributes
        end
      end
    end
  end
end
