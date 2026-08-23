# frozen_string_literal: true

module Poetry
  module Charts
    module RadialBarChart
      # The radial chrome on the cn-chart-* theme rules: the muted
      # track ring, the disc track fills (the first:fill-muted /
      # last:fill-background hack, still explicit), the insideStart label,
      # and the per-family center typography (4xl gauge / 2xl compact;
      # pie keeps 3xl - per upstream).
      class Style < Poetry::Core::Style
        base ""

        element :frame, "contents"
        element :svg, "w-full min-h-0 flex-1"
        element :background_ring, "cn-chart-radial-track"
        element :grid_circle, "cn-chart-polar-grid-circle"
        element :grid_fill_muted, "cn-chart-radial-disc-muted"
        element :grid_fill_background, "cn-chart-radial-disc-background"
        element :inside_label, "cn-chart-radial-inside-label"
        element :center_title, "cn-chart-center-title-radial"
        element :center_title_compact, "cn-chart-center-title-compact"
        element :center_subtitle, "cn-chart-center-subtitle"
      end
    end
  end
end
