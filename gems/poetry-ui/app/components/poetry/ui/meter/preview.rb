# frozen_string_literal: true

module Poetry
  module Ui
    module Meter
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(value: 62, label: "Storage used")
        end

        # value_text: replaces the readout AND aria-valuetext verbatim.
        def with_value_text
          render_component(value: 3, max: 4, label: "Seats", value_text: "3 of 4 seats")
        end

        # A non-zero minimum: the readout is the fraction of the RANGE.
        def with_range
          render_component(value: 210, min: 100, max: 300, label: "Battery voltage",
                           value_text: "210 V")
        end

        def without_readout
          render_component(value: 45, label: "Password strength", show_value: false)
        end
      end
    end
  end
end
