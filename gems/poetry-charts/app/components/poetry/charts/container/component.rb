# frozen_string_literal: true

module Poetry
  module Charts
    module Container
      # The chart frame (shadcn ChartContainer): the engine-agnostic outer
      # layer every chart (poetry's own SVG engine, an adapter engine, or a
      # Stimulus-mounted island) sits inside. It scopes the chart id, emits
      # the per-series --color-<key> custom properties from the config
      # (ThemeStyle, both themes), and carries the aspect-ratio sizing
      # chrome. The content block is the chart body.
      #
      # @example
      #   <%= poetry_chart_container(config: { desktop: { label: "Desktop", color: "var(--chart-1)" } }) do %>
      #     ...the chart body...
      #   <% end %>
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "Every chart lives inside poetry_chart_container(config:) - the config maps series keys to labels/colors.",
          "Reference series colors as var(--color-<key>); never hard-code a color in chart markup.",
          "Config colors point at theme tokens (var(--chart-1..5)) or use theme: { light:, dark: } maps.",
          "Give charts an explicit id: when the page renders more than one of the same chart."
        ].freeze

        option :config, ActiveModel::Type::Value.new, required: true
        option :id, :string

        part "chart", "The chart frame (<div>) - the aspect-video chrome, the tooltip layer's " \
                      "positioning anchor, and the id scope the per-series colors are emitted for",
             states: {
               "data-chart" => "always - the chart instance id (explicit id: or unique per " \
                               "render); the scoped color emission keys off it"
             },
             vars: {
               "--color-*" => "per-series color, one entry per series key - the frame's " \
                              "<style> block emits them for [data-chart=<id>] in both themes"
             }

        def chart_config
          @chart_config ||= Poetry::Charts::Config.wrap(config)
        end

        # The data-chart scope: explicit id when given (stable for tests /
        # multiple charts), else unique per render (shadcn's useId move).
        def chart_id
          @chart_id ||= (dom_id_token(id) ? "chart-#{dom_id_token(id)}" : poetry_instance_id("chart"))
        end

        def theme_css
          Poetry::Charts::ThemeStyle.new(id: chart_id, config: chart_config).css
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "chart",
              "data-chart" => chart_id
            }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
