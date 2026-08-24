# frozen_string_literal: true

module Poetry
  module Charts
    # The chart families' internal hover-tooltip mount.
    module TooltipLayer
      # The hidden tooltip box a chart family renders when with_tooltip is
      # set: the TooltipContent chrome pre-rendered with one row per series
      # (names and indicator colors resolved server-side), positioned and
      # text-swapped by the tooltip controller. Rendered by the chart
      # families, never composed directly.
      # @api private
      class Component < Poetry::Core::Component
        # The box is the parent frame controller's tooltip target - no
        # registration here (TooltipWiring registers on the chart frame).
        use_stimulus do
          on :root do
            controller(TooltipWiring::CONTROLLER) { target :tooltip }
          end
        end

        # The series config - key => { label:, color: } - resolving row
        # names and colors.
        option :config, ActiveModel::Type::Value.new, required: true
        # The series keys to pre-render rows for.
        option :series_keys, ActiveModel::Type::Value.new, required: true
        # The row swatch shape.
        option :indicator, :symbol, default: :dot
        # Hides the category label.
        option :hide_label, :boolean, default: false
        # Hides the row swatches.
        option :hide_indicator, :boolean, default: false

        # The config: option wrapped as a {Poetry::Charts::Config}.
        # @api private
        def chart_config
          @chart_config ||= Poetry::Charts::Config.wrap(config)
        end

        # Placeholder rows: value 0 guarantees the value span exists for
        # the controller to swap; the box is hidden until a point is active.
        # @api private
        def items
          series_keys.map { |key| { key: key, value: 0 } }
        end

        # The hidden box's attributes: part self-identification plus the
        # parent frame controller's tooltip target.
        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "chart-tooltip",
              "hidden" => ""
            }.merge(stimulus_attributes_for(:root))
              .merge(component_data_attributes)
          )
        end
      end
    end
  end
end
