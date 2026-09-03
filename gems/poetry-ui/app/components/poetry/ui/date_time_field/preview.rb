# frozen_string_literal: true

module Poetry
  module Ui
    module DateTimeField
      # The DateTimeField preview: empty and valued fields, seconds, a
      # pinned 24-hour cycle, disabled, invalid, and a pinned locale.
      class Preview < Poetry::Core::Preview::Base
        # Empty: date placeholders then hour/minute (plus AM/PM under
        # twelve-hour locales) once enhanced; the styled native input before that.
        def default
          render_component(name: "event[starts_at]", label: "Starts")
        end

        def with_value
          render_component(name: "event[starts_at]", value: "2026-07-13T13:05", label: "Starts")
        end

        def with_seconds
          render_component(name: "job[run_at]", value: "2026-07-13T09:30:15", seconds: true, label: "Run at")
        end

        # A pinned 24-hour cycle regardless of the page locale.
        def twenty_four_hour
          render_component(name: "shift[starts_at]", value: "2026-07-13T21:15", hour_cycle: "h23", label: "Shift start")
        end

        def disabled
          render_component(name: "event[starts_at]", value: "2026-07-13T13:05", disabled: true, label: "Starts")
        end

        def invalid
          render_component(name: "event[starts_at]", value: "2026-07-13T13:05", invalid: true, label: "Starts")
        end

        # locale: pins the order, separators, and cycle instead of following the page locale.
        def localized
          render_component(name: "termin[beginn]", value: "2026-07-13T14:30", locale: "de-DE", label: "Beginn")
        end
      end
    end
  end
end
