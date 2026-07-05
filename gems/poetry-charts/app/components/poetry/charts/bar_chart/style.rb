# frozen_string_literal: true

module Poetry
  module Charts
    module BarChart
      # The cartesian chrome (see AreaChart::Style for the recharts-override
      # mapping) + the bar label look.
      class Style < Poetry::Core::Style
        base ""

        element :svg, "size-full"
        element :grid_line, "stroke-border/50"
        element :tick, "fill-muted-foreground"
        element :label, "fill-foreground"
      end
    end
  end
end
