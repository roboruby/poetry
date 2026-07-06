# frozen_string_literal: true

module Poetry
  module Ui
    module DatePicker
      # The DatePicker preview: the empty (placeholder) trigger and a
      # preselected one (server-formatted, no JS).
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(name: "due_on", label: "Due date")
        end

        def preselected
          render_component(name: "due_on", label: "Due date", value: "2026-06-12", month: "2026-06-01")
        end

        def range
          render_component(name: "stay", mode: :range, label: "Stay dates",
                           placeholder: "Pick a date range",
                           value: %w[2026-06-09 2026-06-18], month: "2026-06-01")
        end
      end
    end
  end
end
