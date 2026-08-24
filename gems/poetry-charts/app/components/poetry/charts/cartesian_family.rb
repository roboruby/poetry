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
    module CartesianFamily
      def self.included(base)
        base.extend(ClassMethods)

        base.renders_one :x_axis, lambda { |data_key:, tick_formatter: nil, tick_margin: 8|
          @x_axis_config = AxisConfig.new(data_key: data_key.to_s, tick_formatter:, tick_margin:, tick_count: nil)
          nil
        }

        base.value_axis_slot

        base.renders_one :grid, lambda { |vertical: false, horizontal: true|
          @grid_config = GridConfig.new(vertical:, horizontal:)
          nil
        }

        base.renders_one :legend, lambda { |**options|
          @legend_config = options
          nil
        }

        # The slot captures options only; the tooltip layer itself
        # (controller + chrome wiring) is declared by TooltipWiring.
        base.renders_one :tooltip, lambda { |**options|
          @tooltip_config = options
          nil
        }
      end

      module ClassMethods
        # The default numeric Y axis (tickCount 3, no data key).
        def value_axis_slot
          renders_one :y_axis, lambda { |tick_count: 3, tick_formatter: nil, tick_margin: 8|
            @y_axis_config = AxisConfig.new(data_key: nil, tick_formatter:, tick_margin:, tick_count:)
            nil
          }
        end
      end

      def x_axis_config
        x_axis?
        @x_axis_config
      end

      def y_axis_config
        y_axis?
        @y_axis_config
      end

      def grid_config
        grid?
        @grid_config
      end
    end
  end
end
