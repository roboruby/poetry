# frozen_string_literal: true

module Poetry
  module Ui
    module NumberField
      # @label Number Field
      class Preview < Poetry::Core::Preview::Base
        # @!group Basics

        def default
          render_component({ name: "quantity", label: "Quantity", value: 5, min: 0, max: 100 })
        end

        def empty
          render_component({ name: "amount", label: "Amount", placeholder: "0" })
        end

        def decimal_steps
          render_component({ name: "opacity", label: "Opacity", value: 0.5, min: 0, max: 1, step: 0.1 })
        end

        def snapped
          render_component({ name: "duration", label: "Duration", value: 15, min: 0, max: 120, step: 15, snap: true })
        end

        # wheel: opts the focused input into scroll-to-step (off by
        # default - a page-scroll trap otherwise).
        def wheel_stepping
          render_component({ name: "zoom", label: "Zoom", value: 100, min: 25, max: 400, step: 25, wheel: true })
        end

        # @!endgroup

        # @!group Formatted

        def currency
          render_component({ name: "price", label: "Price", value: 1234.5, min: 0, step: 0.5,
                             format: { style: "currency", currency: "USD" }, locale: "en-US" })
        end

        def percent
          render_component({ name: "ratio", label: "Ratio", value: 0.25, min: 0, max: 1, step: 0.05,
                             format: { style: "percent" }, locale: "en-US" })
        end

        # @!endgroup

        # @!group States

        def disabled
          render_component({ name: "locked", label: "Locked quantity", value: 42, disabled: true })
        end

        def invalid
          render_component({ name: "faulty", label: "Faulty quantity", value: 999, invalid: true })
        end

        def readonly
          render_component({ name: "fixed", label: "Fixed quantity", value: 7, readonly: true })
        end

        # @!endgroup
      end
    end
  end
end
