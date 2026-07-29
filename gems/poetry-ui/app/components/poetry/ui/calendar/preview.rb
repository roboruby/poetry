# frozen_string_literal: true

module Poetry
  module Ui
    module Calendar
      # The Calendar preview: a fixed month (deterministic screenshots) with
      # a selected day and today, and a range-bounded variant.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(month: "2026-06-01", selected: "2026-06-12", today: "2026-06-15",
                           class: "rounded-md border")
        end

        def bounded
          render_component(month: "2026-06-01", today: "2026-06-15",
                           min: "2026-06-08", max: "2026-06-22", class: "rounded-md border")
        end

        def range
          render_component(mode: :range, month: "2026-06-01", today: "2026-06-15",
                           selected: Date.new(2026, 6, 9)..Date.new(2026, 6, 18),
                           class: "rounded-md border")
        end

        # caption_layout: :dropdown - the month/year NativeSelect pair;
        # min/max pin the year list (deterministic options).
        def dropdown_caption
          render_component(month: "2026-06-01", selected: "2026-06-12", today: "2026-06-15",
                           caption_layout: :dropdown, min: "2024-01-01", max: "2028-12-31",
                           class: "rounded-md border")
        end

        # week_numbers: the ISO week column (June 2026 = weeks 23-28).
        def week_numbers
          render_component(month: "2026-06-01", selected: "2026-06-12", today: "2026-06-15",
                           week_numbers: true, class: "rounded-md border")
        end
      end
    end
  end
end
