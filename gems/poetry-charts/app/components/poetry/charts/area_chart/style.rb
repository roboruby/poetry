# frozen_string_literal: true

module Poetry
  module Charts
    module AreaChart
      # The cartesian chart chrome, riding the SHARED cn-chart-* theme
      # rules - poetry's equivalent of upstream's [&_.recharts-*]
      # container overrides, landed on parts poetry owns. Series
      # fill/stroke are var(--color-<key>) ATTRIBUTES, never classes.
      class Style < Poetry::Core::Style
        base ""

        element :frame, "contents"
        element :svg, "w-full min-h-0 flex-1"
        element :grid_line, "cn-chart-grid-line"
        element :tick, "cn-chart-tick"
        element :cursor_line, "cn-chart-cursor-line"
        element :cursor_band, "cn-chart-cursor-band"
        element :reference_line, "cn-chart-reference-line"
        element :reference_area, "cn-chart-reference-area"
        element :reference_dot, "cn-chart-reference-dot"
        element :error_bar, "cn-chart-error-bar"
        element :brush_track, "cn-chart-brush-track"
        element :brush_window, "cn-chart-brush-window"
        element :brush_handle, "cn-chart-brush-handle"
      end
    end
  end
end
