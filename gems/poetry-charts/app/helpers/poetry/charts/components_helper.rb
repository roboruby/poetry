# frozen_string_literal: true

module Poetry
  module Charts
    # The poetry_chart_* view helpers - the agent-facing chart surface.
    # The chart-root helpers (poetry_chart :area, ...) arrive with the
    # engine (N10 W3+); W1 ships the frame.
    module ComponentsHelper
      def poetry_chart_container(**, &)
        render(Poetry::Charts::Container::Component.new(**), &)
      end

      def poetry_chart_tooltip_content(**, &)
        render(Poetry::Charts::TooltipContent::Component.new(**), &)
      end

      def poetry_chart_legend_content(**, &)
        render(Poetry::Charts::LegendContent::Component.new(**), &)
      end
    end
  end
end
