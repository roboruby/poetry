# frozen_string_literal: true

module Poetry
  module Charts
    module ComposedChart
      # The composed chrome on the shared cn-chart-* theme rules (N11).
      # Mark fills/strokes are var(--color-<key>) ATTRIBUTES.
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
      end
    end
  end
end
