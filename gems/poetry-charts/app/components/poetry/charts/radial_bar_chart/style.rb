# frozen_string_literal: true

module Poetry
  module Charts
    module RadialBarChart
      # The radial chrome: the muted track ring behind bars, the disc
      # track fills (the shape/text blocks' first:fill-muted
      # last:fill-background hack made explicit), and the insideStart
      # label look (fill-white capitalize mix-blend-luminosity, 11px).
      class Style < Poetry::Core::Style
        base ""

        element :frame, "contents"
        element :svg, "size-full"
        element :background_ring, "fill-muted"
        element :grid_circle, "fill-none stroke-border/50"
        element :grid_fill_muted, "fill-muted"
        element :grid_fill_background, "fill-background"
        element :inside_label, "fill-white capitalize mix-blend-luminosity text-[11px]"
        element :center_title, "fill-foreground text-3xl font-bold"
        element :center_subtitle, "fill-muted-foreground"
      end
    end
  end
end
