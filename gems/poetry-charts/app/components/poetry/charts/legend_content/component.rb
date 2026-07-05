# frozen_string_literal: true

module Poetry
  module Charts
    module LegendContent
      # The legend chrome (shadcn ChartLegendContent): a centered row of
      # swatch + label pairs. Items default to the config's colored entries
      # (the common case - every configured series, in config order); pass
      # items: [{ key:, color: }] to override, e.g. per-slice pie legends.
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "The legend derives from the chart config by default - omit items: unless slices differ from series.",
          "align: :top pads below (pb-3), :bottom (default) pads above (pt-3) - matching the chart edge it sits on."
        ].freeze

        option :config, ActiveModel::Type::Value.new, required: true
        option :items, ActiveModel::Type::Value.new
        option :hide_icon, :boolean, default: false

        # A style axis, not an option - options silently drop the
        # dictionary's variant classes (the N9 W1a learning).
        style :align, default: :bottom, required: true, variants: %i[top bottom]

        def chart_config
          @chart_config ||= Poetry::Charts::Config.wrap(config)
        end

        def rows
          @rows ||= if items.present?
                      Array(items).map { |item| resolve(item.symbolize_keys) }
                    else
                      chart_config.color_entries.map do |entry|
                        { name: entry.label || entry.key, color: entry.color_for(:light) ? swatch_color(entry) : nil }
                      end
                    end
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "chart-legend-content" }.merge(component_data_attributes)
          )
        end

        def swatch_style(color)
          return nil unless color
          raise ArgumentError, "legend color #{color.inspect} is not CSS-safe" unless color.match?(Config::COLOR)

          "background-color: #{color};"
        end

        private

        # Themed entries swatch through var(--color-<key>) (the container's
        # emission), so the swatch follows dark mode; flat colors inline.
        def swatch_color(entry)
          entry.theme ? "var(--color-#{entry.key})" : entry.color
        end

        def resolve(item)
          key = (item[:key] || item[:name]).to_s
          entry = chart_config[key]
          {
            name: chart_config.label_for(key, item[:name]),
            color: item[:color] || (entry && swatch_color(entry))
          }
        end
      end
    end
  end
end
