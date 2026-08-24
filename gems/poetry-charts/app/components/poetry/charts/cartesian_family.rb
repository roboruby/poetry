# frozen_string_literal: true

module Poetry
  module Charts
    # The shared cartesian slot grammar (area/line/bar/composed): the
    # axis/grid/legend/tooltip slots plus the readers that force their
    # lazy evaluation. Lambda slots accumulate config into ivars and
    # return nil (the breadcrumb pattern - slot wrappers do not delegate
    # to lambda return values); readers force evaluation via the slot
    # predicate (slots evaluate lazily).
    #
    # Slots register at the include site because declaration order IS the
    # registry's slot order - include this AFTER the family's mark slots.
    # The value axis is a class-method hook: a family whose Y side
    # diverges (bar - the horizontal orientation moves the category axis
    # there) defines its own value_axis_slot before including.
    #
    # @example Adding the cartesian slot grammar to a family
    #   class StepChart::Component < Poetry::Core::Component
    #     include Poetry::Charts::ChartFamily
    #
    #     # Mark slots first - declaration order is the registry's slot order.
    #     renders_many :steps, lambda { |data_key:| ... }
    #
    #     include Poetry::Charts::CartesianFamily
    #   end
    module CartesianFamily
      def self.included(base)
        base.extend(ClassMethods)

        # The category axis: data_key: names the field ticks label;
        # tick_formatter: reshapes each label; tick_margin: pads it from
        # the plot.
        base.renders_one :x_axis, lambda { |data_key:, tick_formatter: nil, tick_margin: 8|
          @x_axis_config = AxisConfig.new(data_key: data_key.to_s, tick_formatter:, tick_margin:, tick_count: nil)
          nil
        }

        base.value_axis_slot

        # The gridlines: horizontal rules by default; vertical: true adds
        # column rules.
        base.renders_one :grid, lambda { |vertical: false, horizontal: true|
          @grid_config = GridConfig.new(vertical:, horizontal:)
          nil
        }

        # The legend row under the plot: align:, items:, hide_icon:, and
        # toggle: (live charts only - clicking an entry hides its series).
        base.renders_one :legend, lambda { |**options|
          @legend_config = options
          nil
        }

        # The hover tooltip: indicator:, hide_label:, hide_indicator:, and
        # cursor: (the hover rule/band, on by default). The slot captures
        # options only; the tooltip layer itself (controller + chrome
        # wiring) is declared by TooltipWiring.
        base.renders_one :tooltip, lambda { |**options|
          @tooltip_config = options
          nil
        }
      end

      # The class-level hooks the include site drives.
      module ClassMethods
        # Declares the default numeric Y axis slot (tick count 3, no data
        # key). Families whose value axis diverges override this before
        # including the concern.
        def value_axis_slot
          # The value axis: tick_count: sets how many ticks show;
          # tick_formatter: reshapes each label; tick_margin: pads it.
          renders_one :y_axis, lambda { |tick_count: 3, tick_formatter: nil, tick_margin: 8|
            @y_axis_config = AxisConfig.new(data_key: nil, tick_formatter:, tick_margin:, tick_count:)
            nil
          }
        end
      end

      # The x-axis slot's captured config, forcing lazy slot evaluation.
      # @api private
      def x_axis_config
        x_axis?
        @x_axis_config
      end

      # The y-axis slot's captured config, forcing lazy slot evaluation.
      # @api private
      def y_axis_config
        y_axis?
        @y_axis_config
      end

      # The grid slot's captured config, forcing lazy slot evaluation.
      # @api private
      def grid_config
        grid?
        @grid_config
      end
    end
  end
end
