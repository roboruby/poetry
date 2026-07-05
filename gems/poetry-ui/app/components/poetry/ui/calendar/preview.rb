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
      end
    end
  end
end
