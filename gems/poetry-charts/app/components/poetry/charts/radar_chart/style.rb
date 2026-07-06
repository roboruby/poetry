# frozen_string_literal: true

module Poetry
  module Charts
    module RadarChart
      # The radar chrome on the cn-chart-* theme rules (N11): polar grid
      # lines take FULL border (cartesian grids use /50, polar does not).
      # The tinted grid-fill discs keep stroke-none inline (no paint - a
      # mechanism guard, they overlay the linework).
      class Style < Poetry::Core::Style
        base ""

        element :frame, "contents"
        element :svg, "w-full min-h-0 flex-1"
        element :grid_line, "cn-chart-polar-grid-line"
        element :grid_fill, "stroke-none"
        element :tick, "cn-chart-tick"
      end
    end
  end
end
