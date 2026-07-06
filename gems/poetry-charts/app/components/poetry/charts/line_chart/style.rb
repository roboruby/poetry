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
        element :reference_line, "stroke-muted-foreground"
        element :reference_area, "fill-muted-foreground"
        element :reference_dot, "fill-background stroke-muted-foreground"
        element :error_bar, "stroke-foreground"
        element :brush_track, "fill-muted"
        element :brush_window, "fill-foreground/10 stroke-border"
        element :brush_handle, "fill-muted-foreground"
        element :label, "fill-foreground"
      end
    end
  end
end
