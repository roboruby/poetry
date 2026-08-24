# frozen_string_literal: true

module Poetry
  module Charts
    module Container
      # The chart frame chrome, with NO descendant overrides into the
      # chart body - descendant selectors exist to style DOM one does not
      # own, and poetry OWNS its SVG, so tick text (muted-foreground),
      # grid (border/50), and sector/dot outline-hidden land as direct
      # classes on the engine's own parts; the container keeps only what
      # is truly container-level. Adapter/island content brings its own
      # inner styling (a declared degradation).
      class Style < Poetry::Core::Style
        # relative anchors the absolute tooltip layer (visual no-op).
        # flex-col stacks the legend under (or over, via order-first) the
        # chart SVG, reserving plot space for it; a row layout would park
        # the legend beside the plot.
        base "relative flex aspect-video flex-col items-center justify-center text-xs [&_svg]:outline-hidden"
      end
    end
  end
end
