# frozen_string_literal: true

module Poetry
  module Charts
    module Container
      # shadcn ChartContainer chrome (new-york-v4 chart.tsx), minus the
      # [&_.recharts-*] descendant overrides - those exist because shadcn
      # styles DOM it does not own. poetry OWNS its SVG, so the equivalents
      # (tick text = muted-foreground, grid = border/50, sectors/dots
      # outline-hidden) land as direct classes on the engine's own parts
      # when they ship (N10 W3+); the container keeps only what is truly
      # container-level. Adapter/island content brings its own inner styling
      # (a declared degradation).
      class Style < Poetry::Core::Style
        base "flex aspect-video justify-center text-xs [&_svg]:outline-hidden"
      end
    end
  end
end
