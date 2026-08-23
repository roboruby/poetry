# frozen_string_literal: true

module Poetry
  module Charts
    module LegendContent
      # Re-expressed through the cn-* theme layer. flex-wrap stays
      # poetry's one structural addition (long lists wrap in the real flex
      # column); order-first stays inline in the top align (layout
      # mechanism - the padding rides the theme rule). The toggle's
      # data-hidden dim is live-controller state, inline.
      class Style < Poetry::Core::Style
        base "cn-chart-legend flex flex-wrap items-center justify-center"

        variant :align, {
          top: "cn-chart-legend-align-top order-first",
          bottom: "cn-chart-legend-align-bottom"
        }
        element :item, "cn-chart-legend-item flex items-center"
        element :swatch, "cn-chart-legend-swatch shrink-0"
        # Toggle buttons dim when their series hides (the live controller
        # stamps data-hidden).
        element :toggle, "cursor-pointer data-hidden:opacity-40"
      end
    end
  end
end
