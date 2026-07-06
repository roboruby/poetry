# frozen_string_literal: true

module Poetry
  module Charts
    module RadarChart
      # The radar chrome: polar grid lines take FULL border (the chart.tsx
      # [&_.recharts-polar-grid] override - cartesian grids use /50, polar
      # does not), rim labels ride muted-foreground.
      class Style < Poetry::Core::Style
        base ""

        element :frame, "contents"
        element :svg, "w-full min-h-0 flex-1"
        element :grid_line, "fill-none stroke-border"
        element :tick, "fill-muted-foreground"
      end
    end
  end
end
