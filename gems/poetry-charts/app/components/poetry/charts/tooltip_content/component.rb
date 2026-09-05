# frozen_string_literal: true

module Poetry
  module Charts
    # The chart tooltip chrome.
    module TooltipContent
      # The tooltip chrome - the styled info box: optional label, then
      # one row per series item (indicator + name + tabular value). Pure
      # server-rendered markup; the tooltip controller positions and
      # repopulates it from server-embedded coordinates. Indicator colors
      # ride the --color-bg/--color-border inline custom properties, so a
      # row's swatch follows its series.
      #
      # @example
      #   <%= poetry_tooltip_content(config: config,
      #                                    items: [{ key: :desktop, value: 186 }]) %>
      #
      # Items are `{ key:, name:, value:, color: }` hashes; names resolve
      # through the config (config label, else the item name, else the
      # key) and colors fall back to the config entry's color, all
      # server-side.
      class Component < Poetry::Core::Component
        # Projected into the registry and agent surface.
        AGENT_RULES = [
          "Tooltip rows resolve names/colors through the chart config - pass key:, not a display string.",
          "indicator: :dot (default) | :line | :dashed matches the ported variants.",
          "Numeric values render delimited (1,234) in the mono tabular column automatically."
        ].freeze

        option :config, ActiveModel::Type::Value.new, required: true,
                                                      doc: "The series config - key => { label:, color: } - " \
                                                           "resolving row names and colors."
        option :items, ActiveModel::Type::Value.new, required: true,
                                                     doc: "The rows: [{ key:, name:, value:, color: }] hashes, one " \
                                                          "per series."
        option :indicator, :symbol, default: :dot, doc: "The row swatch shape."
        option :label, :string, doc: "The category label above the rows, resolved through the config."
        option :hide_label, :boolean, default: false, doc: "Hides the category label."
        option :hide_indicator, :boolean, default: false, doc: "Hides the row swatches."

        validates :indicator, inclusion: { in: %i[dot line dashed] }

        part "chart-tooltip-content", "The tooltip box (<div>) - the styled chrome the chart's " \
                                      "tooltip controller positions and text-swaps"
        part "chart-tooltip-label", "The category label (<div>) - above the rows, or nested " \
                                    "inside the single row for line/dashed indicators"
        part "chart-tooltip-item", "One series row (<div>) - indicator + name + value",
             states: { "data-key" => "always - the series key the controller matches values by" }
        part "chart-tooltip-indicator", "The row's swatch (<div>) - dot/line/dashed per " \
                                        "indicator:, hidden with hide_indicator",
             vars: {
               "--color-bg" => "the swatch fill - carries the row's series color (inline; polar " \
                               "charts retint it to the hovered slice's color at runtime)",
               "--color-border" => "the swatch border - the same series color as the fill"
             }
        part "chart-tooltip-name", "The series name (<span>) - resolved through the chart config"
        part "chart-tooltip-value", "The formatted value (<span>) - the mono tabular column, " \
                                    "numbers delimited"

        # The config: option wrapped as a {Poetry::Charts::Config}.
        # @api private
        def chart_config
          @chart_config ||= Poetry::Charts::Config.wrap(config)
        end

        # The items resolved into Row objects.
        # @api private
        def rows
          @rows ||= Array(items).map { |item| Row.new(item.symbolize_keys, chart_config) }
        end

        # The label nests inside the single row for line/dashed
        # indicators - the layout that makes the 1-series line-indicator
        # tooltip read as one unit.
        # @api private
        def nest_label?
          rows.length == 1 && indicator != :dot
        end

        # Label resolution: config label for the key when one matches,
        # else the given string.
        # @api private
        def label_text
          return nil if hide_label || label.blank?

          chart_config.label_for(label, label)
        end

        # A row's classes, with the dot layout when the indicator is one.
        # @api private
        def row_classes
          classes = css(:row)
          classes = "#{classes} #{css(:row_dot)}" if indicator == :dot
          classes
        end

        # The swatch's classes for the indicator shape (nested dashes get
        # their own alignment).
        # @api private
        def indicator_classes(nested: false)
          classes = "#{css(:indicator)} #{css(:"indicator_#{indicator}")}"
          classes = "#{classes} #{css(:indicator_dashed_nested)}" if nested && indicator == :dashed
          classes
        end

        # The value column's alignment classes (nested labels bottom-align).
        # @api private
        def value_wrap_classes
          "#{css(:value_wrap)} #{nest_label? ? css(:value_wrap_end) : css(:value_wrap_center)}"
        end

        # The box's attributes with the part self-identification.
        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "chart-tooltip-content" }.merge(component_data_attributes)
          )
        end

        # One resolved tooltip row: name via config, color via item-else-config.
        # @api private
        class Row
          def initialize(item, config)
            @item = item
            @config = config
          end

          def key
            (@item[:key] || @item[:name] || "value").to_s
          end

          def name
            @config.label_for(key, @item[:name])
          end

          def color
            @item[:color] || @config[key]&.color
          end

          def value
            @item[:value]
          end

          def formatted_value
            return nil if value.nil?
            return ActiveSupport::NumberHelper.number_to_delimited(value) if value.is_a?(Numeric)

            value.to_s
          end

          # Guarded inline style: colors reaching a style attribute must be
          # CSS-safe (config colors already are; item colors get the same rule).
          def indicator_style
            return nil unless color
            unless color.match?(Config::COLOR)
              raise ArgumentError, "tooltip item color #{color.inspect} is not CSS-safe"
            end

            "--color-bg: #{color}; --color-border: #{color};"
          end
        end

        private :chart_config, :rows, :nest_label?, :label_text, :row_classes, :indicator_classes, :value_wrap_classes
        private :root_attributes
      end
    end
  end
end
