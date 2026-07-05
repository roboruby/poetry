# frozen_string_literal: true

module Poetry
  module Charts
    # The poetry_chart_* view helpers - the agent-facing chart surface.
    # The chart-root helpers (poetry_chart :area, ...) arrive with the
    # engine (N10 W3+); W1 ships the frame.
    module ComponentsHelper
      # The chart-root dispatcher: poetry_chart :area, data:, config: do |c| ... end
      # Families arrive wave by wave (N10 plan); unknown types raise with
      # the known list (agent-teachable).
      CHART_TYPES = {
        area: "Poetry::Charts::AreaChart::Component",
        line: "Poetry::Charts::LineChart::Component",
        bar: "Poetry::Charts::BarChart::Component",
        pie: "Poetry::Charts::PieChart::Component"
      }.freeze

      def poetry_chart(type, **, &)
        component = CHART_TYPES[type.to_sym] or
          raise ArgumentError, "unknown chart type #{type.inspect} (one of #{CHART_TYPES.keys.join(", ")})"
        render(component.constantize.new(**), &)
      end

      def poetry_area_chart(**, &)
        render(Poetry::Charts::AreaChart::Component.new(**), &)
      end

      def poetry_line_chart(**, &)
        render(Poetry::Charts::LineChart::Component.new(**), &)
      end

      def poetry_bar_chart(**, &)
        render(Poetry::Charts::BarChart::Component.new(**), &)
      end

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
