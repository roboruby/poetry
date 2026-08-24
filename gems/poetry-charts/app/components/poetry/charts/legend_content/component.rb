# frozen_string_literal: true

module Poetry
  module Charts
    # The chart legend chrome.
    module LegendContent
      # The legend chrome: a centered row of swatch + label pairs. Items
      # default to the config's colored entries (the common case - every
      # configured series, in config order); pass items: [{ key:, color: }]
      # to override, e.g. per-slice pie legends.
      #
      # @example
      #   <%= poetry_chart_legend_content(config: config) %>
      class Component < Poetry::Core::Component
        # Projected into the registry and agent surface.
        AGENT_RULES = [
          "The legend derives from the chart config by default - omit items: unless slices differ from series.",
          "align: :top pads below (pb-3), :bottom (default) pads above (pt-3) - matching the chart edge it sits on."
        ].freeze

        # Which chart edge the legend sits on: :top pads below it,
        # :bottom (the default) pads above. A style axis, not an option -
        # options silently drop the dictionary's variant classes.
        style :align, default: :bottom, required: true, variants: %i[top bottom]

        # The series config - key => { label:, color: } - the default
        # item source.
        option :config, ActiveModel::Type::Value.new, required: true
        # Explicit entries ([{ key:, name:, color: }]) overriding the
        # config-derived list.
        option :items, ActiveModel::Type::Value.new
        # Hides the color swatches, leaving labels only.
        option :hide_icon, :boolean, default: false
        # Interactive legend: items render as buttons that toggle
        # their series through the live controller (the host chart guards
        # that live: is on).
        option :toggle, :boolean, default: false

        part "chart-legend-content", "The legend row (<div>) - centered swatch + label pairs"
        part "chart-legend-item", "One legend entry (<div>; a <button> in toggle mode)",
             states: {
               "data-key" => "in toggle mode - the series key the button toggles",
               "data-hidden" => "in toggle mode - the item's series is toggled off (the live " \
                                "controller stamps it at runtime; the item dims)"
             }
        part "chart-legend-swatch", "The color swatch (<div>) - inline background-color carries " \
                                    "the entry's color; omitted with hide_icon or colorless entries"

        # The config: option wrapped as a {Poetry::Charts::Config}.
        # @api private
        def chart_config
          @chart_config ||= Poetry::Charts::Config.wrap(config)
        end

        # The resolved entries: explicit items:, else the config's
        # colored entries in config order.
        # @api private
        def rows
          @rows ||= if items.present?
                      Array(items).map { |item| resolve(item.symbolize_keys) }
                    else
                      chart_config.color_entries.map do |entry|
                        { key: entry.key, name: entry.label || entry.key,
                          color: entry.color_for(:light) ? swatch_color(entry) : nil }
                      end
                    end
        end

        # The toggle buttons speak straight to the live controller on the
        # chart frame (Stimulus action params carry the series key).
        # @api private
        def toggle_attributes(row)
          {
            type: "button",
            data: {
              slot: "chart-legend-item",
              key: row[:key],
              action: "click->poetry--charts--live#toggleSeries",
              "poetry--charts--live-key-param": row[:key]
            },
            class: "#{css(:item)} #{css(:toggle)}"
          }
        end

        # The legend row's attributes with the part self-identification.
        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "chart-legend-content" }.merge(component_data_attributes)
          )
        end

        # A swatch's guarded inline background (colors reaching a style
        # attribute must be CSS-safe).
        # @api private
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
            key: key,
            name: chart_config.label_for(key, item[:name]),
            color: item[:color] || (entry && swatch_color(entry))
          }
        end
      end
    end
  end
end
