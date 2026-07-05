# frozen_string_literal: true

module Poetry
  module Charts
    module LineChart
      # The cartesian chrome (see AreaChart::Style for the recharts-override
      # mapping) + the point-label look (LabelList className fill-foreground).
      class Style < Poetry::Core::Style
        base ""

        element :frame, "contents"
        element :svg, "size-full"
        element :grid_line, "stroke-border/50"
        element :tick, "fill-muted-foreground"
        element :label, "fill-foreground"
      end
    end
  end
end
