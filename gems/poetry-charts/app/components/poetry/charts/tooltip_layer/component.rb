# frozen_string_literal: true

module Poetry
  module Charts
    module TooltipLayer
      # The hidden tooltip box a chart family renders when with_tooltip is
      # set: the TooltipContent chrome pre-rendered with one row per series
      # (names and indicator colors resolved server-side), positioned and
      # text-swapped by the poetry--charts--tooltip controller.
      class Component < Poetry::Core::Component
        option :config, ActiveModel::Type::Value.new, required: true
        option :series_keys, ActiveModel::Type::Value.new, required: true
        option :indicator, :symbol, default: :dot
        option :hide_label, :boolean, default: false
        option :hide_indicator, :boolean, default: false

        def chart_config
          @chart_config ||= Poetry::Charts::Config.wrap(config)
        end

        # Placeholder rows: value 0 guarantees the value span exists for
        # the controller to swap; the box is hidden until a point is active.
        def items
          series_keys.map { |key| { key: key, value: 0 } }
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "chart-tooltip",
              "data-poetry--charts--tooltip-target" => "tooltip",
              "hidden" => ""
            }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
