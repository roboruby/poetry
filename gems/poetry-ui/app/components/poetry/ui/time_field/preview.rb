# frozen_string_literal: true

module Poetry
  module Ui
    module TimeField
      class Preview < Poetry::Core::Preview::Base
        # Empty: hour/minute placeholders (plus AM/PM under twelve-hour
        # locales) once enhanced; the styled native input before that.
        def default
          render_component(name: "meeting[at]", label: "Start time")
        end

        def with_value
          render_component(name: "meeting[at]", value: "13:05", label: "Start time")
        end

        def with_seconds
          render_component(name: "job[cutoff]", value: "09:30:15", seconds: true, label: "Cutoff")
        end

        # A pinned 24-hour cycle regardless of the page locale.
        def twenty_four_hour
          render_component(name: "shift[start]", value: "21:15", hour_cycle: "h23", label: "Shift start")
        end

        def disabled
          render_component(name: "meeting[at]", value: "13:05", disabled: true, label: "Start time")
        end
      end
    end
  end
end
