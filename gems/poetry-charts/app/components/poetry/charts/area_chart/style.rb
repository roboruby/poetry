# frozen_string_literal: true

module Poetry
  module Charts
    module AreaChart
      # The cartesian chart chrome. shadcn provides these looks through the
      # container's [&_.recharts-*] descendant overrides (styling DOM it
      # does not own); poetry OWNS the SVG, so the classes land directly on
      # the parts: tick text = muted-foreground (the
      # recharts-cartesian-axis-tick_text override), grid = border/50 (the
      # recharts-cartesian-grid override). Series fill/stroke are
      # var(--color-<key>) ATTRIBUTES, never classes.
      class Style < Poetry::Core::Style
        base ""

        element :frame, "contents"
        element :svg, "w-full min-h-0 flex-1"
        element :grid_line, "stroke-border/50"
        element :tick, "fill-muted-foreground"
        element :cursor_line, "stroke-border"
        element :cursor_band, "fill-muted"
        element :reference_line, "stroke-muted-foreground"
        element :reference_area, "fill-muted-foreground"
        element :reference_dot, "fill-background stroke-muted-foreground"
        element :error_bar, "stroke-foreground"
        element :brush_track, "fill-muted"
        element :brush_window, "fill-foreground/10 stroke-border"
        element :brush_handle, "fill-muted-foreground"
      end
    end
  end
end
