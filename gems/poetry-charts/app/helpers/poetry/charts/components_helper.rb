# frozen_string_literal: true

module Poetry
  module Charts
    # The poetry_* chart view helpers - the agent-facing chart surface, from
    # the chart-root dispatcher down to one helper per component. Every
    # registered component answers to poetry_<component name>, the
    # convention the registry, `poetry check`, llms.txt, and the skills
    # derive helper names from; the three poetry_chart_* wrappers stay as
    # aliases for callers that adopted them.
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

      # Renders a composed chart - areas, bars, and lines sharing one x band
      # and one y domain; declaration order is paint order.
      #
      # @example
      #   <%= poetry_composed_chart(data: data, config: config) do |c| %>
      #     <% c.with_bar data_key: :desktop %>
      #     <% c.with_line data_key: :mobile %>
      #   <% end %>
      #
      # @see Poetry::Charts::ComposedChart::Component
      def poetry_composed_chart(**, &)
        render(Poetry::Charts::ComposedChart::Component.new(**), &)
      end

      # Renders a pie chart - one or more rings of slices; inner_radius on a
      # pie makes the donut, with_center_label fills the hole.
      #
      # @example
      #   <%= poetry_pie_chart(data: data, config: config) do |c| %>
      #     <% c.with_pie data_key: :visitors, name_key: :browser, inner_radius: 60 %>
      #     <% c.with_tooltip %>
      #   <% end %>
      #
      # @see Poetry::Charts::PieChart::Component
      def poetry_pie_chart(**, &)
        render(Poetry::Charts::PieChart::Component.new(**), &)
      end

      # Renders a radar chart - series drawn as polygons over a polar grid.
      #
      # @example
      #   <%= poetry_radar_chart(data: data, config: config) do |c| %>
      #     <% c.with_radar data_key: :desktop %>
      #   <% end %>
      #
      # @see Poetry::Charts::RadarChart::Component
      def poetry_radar_chart(**, &)
        render(Poetry::Charts::RadarChart::Component.new(**), &)
      end

      # Renders a radial bar chart - values as arcs around a shared center.
      #
      # @example
      #   <%= poetry_radial_bar_chart(data: data, config: config) do |c| %>
      #     <% c.with_radial_bar data_key: :visitors %>
      #   <% end %>
      #
      # @see Poetry::Charts::RadialBarChart::Component
      def poetry_radial_bar_chart(**, &)
        render(Poetry::Charts::RadialBarChart::Component.new(**), &)
      end

      # Renders a scatter chart - points positioned by two numeric keys.
      #
      # @example
      #   <%= poetry_scatter_chart(data: data, config: config) do |c| %>
      #     <% c.with_scatter data_key: :desktop %>
      #   <% end %>
      #
      # @see Poetry::Charts::ScatterChart::Component
      def poetry_scatter_chart(**, &)
        render(Poetry::Charts::ScatterChart::Component.new(**), &)
      end

      # Renders the adapter mount directly - the closed spec (type:,
      # engine:, series:, axes:) handed to a registered client-side engine.
      # poetry_chart(type, engine:) is the same call with the type first.
      #
      # @example
      #   <%= poetry_adapter_chart(type: :line, engine: :chartjs, data: data, config: config,
      #                            series: [{ data_key: :desktop }]) %>
      #
      # @see Poetry::Charts::AdapterChart::Component
      def poetry_adapter_chart(**)
        render(Poetry::Charts::AdapterChart::Component.new(**))
      end

      # Renders the chart container - the sized, theme-scoped wrapper that
      # emits var(--color-<key>) for every configured series and hosts the
      # chart plus its tooltip and legend.
      #
      # @example
      #   <%= poetry_container(config: config, class: "h-64") do %>
      #     <%= poetry_area_chart(data: data, config: config) %>
      #   <% end %>
      #
      # @see Poetry::Charts::Container::Component
      def poetry_container(**, &)
        render(Poetry::Charts::Container::Component.new(**), &)
      end
      alias poetry_chart_container poetry_container

      # Renders the tooltip panel a chart's hover layer positions and fills -
      # place it inside the container alongside the chart.
      #
      # @example
      #   <%= poetry_tooltip_content(indicator: :line) %>
      #
      # @see Poetry::Charts::TooltipContent::Component
      def poetry_tooltip_content(**, &)
        render(Poetry::Charts::TooltipContent::Component.new(**), &)
      end
      alias poetry_chart_tooltip_content poetry_tooltip_content

      # Renders the hover layer that positions the tooltip over a chart -
      # the charts attach it themselves through with_tooltip; reach for the
      # helper only when composing the layer by hand.
      #
      # @example
      #   <%= poetry_tooltip_layer(chart_id: "traffic") %>
      #
      # @see Poetry::Charts::TooltipLayer::Component
      def poetry_tooltip_layer(**, &)
        render(Poetry::Charts::TooltipLayer::Component.new(**), &)
      end

      # Renders a standalone legend for the configured series - a swatch
      # plus label per entry.
      #
      # @example
      #   <%= poetry_legend_content(config: config) %>
      #
      # @see Poetry::Charts::LegendContent::Component
      def poetry_legend_content(**, &)
        render(Poetry::Charts::LegendContent::Component.new(**), &)
      end
      alias poetry_chart_legend_content poetry_legend_content
    end
  end
end
