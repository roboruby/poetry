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
          "name: makes it a form control (the chosen date posts as an ISO string in a hidden input).",
          "month:/selected:/today accept a Date or an ISO string; min:/max: bound the selectable range.",
          "The grid is server-rendered - it shows a valid month with no JS; the controller adds " \
          "navigation + selection.",
          "For a text-field + popover, use DatePicker (it composes this) - a bare Calendar is the " \
          "always-visible grid."
        ].freeze

        CONTROLLER = %i[poetry core calendar].freeze

        option :name, :string
        option :week_start, :integer, default: 0 # 0 = Sunday

        def initialize(month: nil, selected: nil, min: nil, max: nil, today: nil, **) # rubocop:disable Metrics/ParameterLists
          super(**)
          @selected = to_date(selected)
          @today = to_date(today) || Date.today
          @min = to_date(min)
          @max = to_date(max)
          @month = to_date(month) || @selected || @today
        end

        attr_reader :selected, :today, :min, :max

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

        # Exactly one day is the tab stop: the selection, else today (in
        # view), else the first enabled day.
        def tab_stop
          @tab_stop ||= (@selected if @selected && in_month?(@selected)) ||
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
        def cell_attributes(date)
          {
            "role" => "gridcell", "data-slot" => "calendar-day-cell",
            "class" => css(:day_cell), "aria-selected" => selected?(date).to_s
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
          attrs["data-selected"] = "" if selected?(date)
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

        def root_stimulus_attributes
          attrs = Poetry::Core::HTML::Attributes.new
          calendar = Poetry::Core::Stimulus::Builder.new(CONTROLLER, attrs)
          calendar.register_controller
          calendar.with_value(:month, @month.strftime("%Y-%m"))
          calendar.with_value(:selected, @selected&.iso8601 || "")
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
