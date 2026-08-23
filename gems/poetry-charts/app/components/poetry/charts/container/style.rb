# frozen_string_literal: true

module Poetry
  module Charts
    module Container
      # shadcn ChartContainer chrome (new-york-v4 chart.tsx), minus the
      # [&_.recharts-*] descendant overrides - those exist because shadcn
      # styles DOM it does not own. poetry OWNS its SVG, so the equivalents
      # (tick text = muted-foreground, grid = border/50, sectors/dots
      # outline-hidden) land as direct classes on the engine's own parts;
      # the container keeps only what is truly container-level.
      # Adapter/island content brings its own inner styling (a declared
      # degradation).
      class Style < Poetry::Core::Style
        # relative anchors the absolute tooltip layer (visual no-op).
        # flex-col stacks the legend under (or over, via order-first) the
        # chart SVG - recharts reserves plot space for its Legend the same
        # way; a row layout would park the legend beside the plot.
        base "relative flex aspect-video flex-col items-center justify-center text-xs [&_svg]:outline-hidden"
      end
    end
  end
end
