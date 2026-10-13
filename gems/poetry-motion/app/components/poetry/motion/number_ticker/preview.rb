# frozen_string_literal: true

module Poetry
  module Motion
    module NumberTicker
      # Number ticker previews: a count, currency, a percentage, and one on load.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(value: 12_480, class: "text-4xl font-semibold")
        end

        def currency
          render_component(value: 48_250.5, format: { style: "currency", currency: "USD", minimumFractionDigits: 2 },
                           class: "text-4xl font-semibold")
        end

        def percentage
          render_component(value: 0.982, format: { style: "percent", maximumFractionDigits: 1 },
                           class: "text-4xl font-semibold")
        end

        def on_load
          render_component(value: 3_200, from: 1_000, trigger: :load, spring: :snappy, class: "text-4xl font-semibold")
        end
      end
    end
  end
end
