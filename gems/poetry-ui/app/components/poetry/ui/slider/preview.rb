# frozen_string_literal: true

module Poetry
  module Ui
    module Slider
      # The Slider preview matrix: modes (single, range, range+gap) x
      # orientation x states, the slider-demo port, and the edge
      # geometries (pinned at min/max, decimal step, inverted).
      class Preview < Poetry::Core::Preview::Base
        # @!group Modes

        # The slider-demo port: defaultValue [50], max 100, step 1,
        # constrained width.
        def default
          render_component(name: "progress", value: 50, label: "Progress", class: "w-[60%]")
        end

        # Range mode (field-slider parity): two thumbs, name[] array
        # params, TWO distinct thumb names (enforced).
        def range
          render_component(name: "price_range", values: [200, 800], min: 0, max: 1000, step: 10,
                           label: ["Minimum price", "Maximum price"],
                           value_text: ->(value) { "$#{value}" })
        end

        # min_steps_between_thumbs: the thumbs can never close under
        # 10 steps - Home/End clamp at the neighbor's gap.
        def range_with_gap
          render_component(name: "hours", values: [9, 17], min: 0, max: 24,
                           min_steps_between_thumbs: 4,
                           label: %w[Start End])
        end

        # @!endgroup

        # @!group Geometry

        # Vertical grows BOTTOM-up (APG); ArrowUp still increments.
        def vertical
          render_component(name: "volume", value: 65, orientation: :vertical, label: "Volume",
                           value_text: ->(value) { "#{value}%" }, class: "h-48")
        end

        # inverted: the value direction flips along the axis (increment
        # keys decrement); composes with RTL (both = ltr math).
        def inverted
          render_component(name: "depth", value: 30, inverted: true, label: "Depth")
        end

        # Decimal step: the controller's precision-aware rounding keeps
        # 0.1 grids exact (0.3, never 0.30000000000000004).
        def decimal_step
          render_component(name: "opacity", value: 0.5, min: 0, max: 1, step: 0.1, label: "Opacity")
        end

        # Pinned at the edges: range renders 0%/100% deterministically.
        def at_the_edges
          render_component(name: "bounds", values: [0, 100], label: %w[Low High])
        end

        # @!endgroup

        # @!group States

        def disabled
          render_component(name: "volume", value: 40, disabled: true, label: "Volume")
        end

        # @!endgroup
      end
    end
  end
end
