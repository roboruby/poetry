# frozen_string_literal: true

module Poetry
  module Charts
    # The chart container.
    module Container
      # The chart frame: the engine-agnostic outer layer every chart
      # (poetry's own SVG engine, an adapter engine, or a
      # Stimulus-mounted island) sits inside. It scopes the chart id, emits
      # the per-series --color-<key> custom properties from the config
      # (ThemeStyle, both themes), and carries the aspect-ratio sizing
      # chrome. The content block is the chart body.
      #
      # @example
      #   <%= poetry_container(config: { desktop: { label: "Desktop", color: "var(--chart-1)" } }) do %>
      #     ...the chart body...
      #   <% end %>
      class Component < Poetry::Core::Component
        # Projected into the registry and agent surface.
        AGENT_RULES = [
          "Every chart lives inside poetry_container(config:) - the config maps series keys to labels/colors.",
          "Reference series colors as var(--color-<key>); never hard-code a color in chart markup.",
          "Config colors point at theme tokens (var(--chart-1..5)) or use theme: { light:, dark: } maps.",
          "Give charts an explicit id: when the page renders more than one of the same chart."
        ].freeze

        option :config, ActiveModel::Type::Value.new, required: true,
                                                      doc: "The series config - key => { label:, color: } - driving " \
                                                           "the per-series color emission."
        option :id, :string,
               doc: "Explicit DOM id token, stable across renders; otherwise the frame gets a unique per-render id."

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

        # The config: option wrapped as a {Poetry::Charts::Config}.
        # @api private
        def chart_config
          @chart_config ||= Poetry::Charts::Config.wrap(config)
        end

        # The data-chart scope: explicit id when given (stable for tests /
        # multiple charts), else unique per render.
        # @api private
        def chart_id
          @chart_id ||= (dom_id_token(id) ? "chart-#{dom_id_token(id)}" : poetry_instance_id("chart"))
        end

        # The scoped per-series color declarations for the frame's
        # <style> block, both themes.
        # @api private
        def theme_css
          Poetry::Charts::ThemeStyle.new(id: chart_id, config: chart_config).css
        end

        # The frame div's attributes: part self-identification plus the
        # data-chart scope.
        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "chart",
              "data-chart" => chart_id
            }.merge(component_data_attributes)
          )
        end

        private :chart_config, :chart_id, :theme_css, :root_attributes
      end
    end
  end
end
