# frozen_string_literal: true

module Poetry
  module Charts
    module ComposedChart
      # The composed chrome mirrors the cartesian families: muted ticks,
      # border/50 grid. Mark fills/strokes are var(--color-<key>) ATTRIBUTES.
      class Style < Poetry::Core::Style
        base ""

        element :frame, "contents"
        element :svg, "size-full"
        element :grid_line, "stroke-border/50"
        element :tick, "fill-muted-foreground"
        element :cursor_line, "stroke-border"
        element :cursor_band, "fill-muted"
        element :reference_line, "stroke-muted-foreground"
        element :reference_area, "fill-muted-foreground"
        element :reference_dot, "fill-background stroke-muted-foreground"
        element :error_bar, "stroke-foreground"
      end
    end
  end
end
