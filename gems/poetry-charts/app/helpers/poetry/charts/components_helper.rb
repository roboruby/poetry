# frozen_string_literal: true

module Poetry
  module Charts
    # The poetry_chart_* view helpers - the agent-facing chart surface,
    # from the chart-root dispatcher down to the per-family helpers.
    module ComponentsHelper
      # Chart type symbols mapped to their component class names - the
      # dispatch table behind poetry_chart.
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

      # Renders a chart of the given type through one dispatcher; the block
      # receives the chart component for slot composition. Unknown types
      # raise with the list of known ones.
      #
      # @example
      #   <%= poetry_chart(:area, data: data, config: config) do |c| %>
      #     <% c.with_area data_key: :desktop %>
      #   <% end %>
      #
      # @param type [Symbol, String] one of the CHART_TYPES keys
      # @param engine [Symbol, nil] when set, routes the call to the
      #   client-side adapter mount, which takes series:/axes: arguments
      #   (the closed spec) instead of slots
      # @see Poetry::Charts::AdapterChart::Component
      def poetry_chart(type, engine: nil, **, &block)
        # The one-word swap: engine: routes the same call to
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

      # Renders an area chart - filled trends over an ordered axis,
      # optionally stacked.
      #
      # @example
      #   <%= poetry_area_chart(data: data, config: config) do |c| %>
      #     <% c.with_area data_key: :desktop %>
      #   <% end %>
      #
      # @see Poetry::Charts::AreaChart::Component
      def poetry_area_chart(**, &)
        render(Poetry::Charts::AreaChart::Component.new(**), &)
      end

      # Renders a line chart - one stroked curve per series.
      #
      # @example
      #   <%= poetry_line_chart(data: data, config: config) do |c| %>
      #     <% c.with_line data_key: :desktop %>
      #   <% end %>
      #
      # @see Poetry::Charts::LineChart::Component
      def poetry_line_chart(**, &)
        render(Poetry::Charts::LineChart::Component.new(**), &)
      end

      # Renders a bar chart - grouped or stacked rectangles per category.
      #
      # @example
      #   <%= poetry_bar_chart(data: data, config: config) do |c| %>
      #     <% c.with_bar data_key: :desktop %>
      #   <% end %>
      #
      # @see Poetry::Charts::BarChart::Component
      def poetry_bar_chart(**, &)
        render(Poetry::Charts::BarChart::Component.new(**), &)
      end

      # Renders the chart container - the sized, theme-scoped wrapper that
      # emits var(--color-<key>) for every configured series and hosts the
      # chart plus its tooltip and legend.
      #
      # @example
      #   <%= poetry_chart_container(config: config, class: "h-64") do %>
      #     <%= poetry_area_chart(data: data, config: config) %>
      #   <% end %>
      #
      # @see Poetry::Charts::Container::Component
      def poetry_chart_container(**, &)
        render(Poetry::Charts::Container::Component.new(**), &)
      end

      # Renders the tooltip panel a chart's hover layer positions and fills -
      # place it inside the container alongside the chart.
      #
      # @example
      #   <%= poetry_chart_tooltip_content(indicator: :line) %>
      #
      # @see Poetry::Charts::TooltipContent::Component
      def poetry_chart_tooltip_content(**, &)
        render(Poetry::Charts::TooltipContent::Component.new(**), &)
      end

      # Renders a standalone legend for the configured series - a swatch
      # plus label per entry.
      #
      # @example
      #   <%= poetry_chart_legend_content(config: config) %>
      #
      # @see Poetry::Charts::LegendContent::Component
      def poetry_chart_legend_content(**, &)
        render(Poetry::Charts::LegendContent::Component.new(**), &)
      end
    end
  end
end
