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
        pie: "Poetry::Charts::PieChart::Component",
        radial: "Poetry::Charts::RadialBarChart::Component",
        radar: "Poetry::Charts::RadarChart::Component",
        scatter: "Poetry::Charts::ScatterChart::Component",
        composed: "Poetry::Charts::ComposedChart::Component"
      }.freeze

      def poetry_chart(type, engine: nil, **, &block)
        # The one-word swap (Door 2): engine: routes the same call to
        # the adapter mount, which consumes the closed spec instead of slots.
        if engine
          if block
            raise ArgumentError,
                  "the adapter path takes series:/axes: arguments (the closed spec), not slots"
          end
          return render(Poetry::Charts::AdapterChart::Component.new(type: type, engine: engine, **))
        end

        component = CHART_TYPES[type.to_sym] or
          raise ArgumentError, "unknown chart type #{type.inspect} (one of #{CHART_TYPES.keys.join(", ")})"
        render(component.constantize.new(**), &block)
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
