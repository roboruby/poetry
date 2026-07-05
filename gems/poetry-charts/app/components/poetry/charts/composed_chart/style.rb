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
      end
    end
  end
end
