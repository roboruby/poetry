# frozen_string_literal: true

module Poetry
  module Charts
    module ScatterChart
      # The scatter chrome mirrors the cartesian families: muted ticks,
      # border/50 grid. Point fills are var(--color-<key>) ATTRIBUTES.
      class Style < Poetry::Core::Style
        base ""

        element :frame, "contents"
        element :svg, "w-full min-h-0 flex-1"
        element :grid_line, "stroke-border/50"
        element :tick, "fill-muted-foreground"
        element :reference_line, "stroke-muted-foreground"
        element :reference_area, "fill-muted-foreground"
        element :reference_dot, "fill-background stroke-muted-foreground"
        element :error_bar, "stroke-foreground"
      end
    end
  end
end
