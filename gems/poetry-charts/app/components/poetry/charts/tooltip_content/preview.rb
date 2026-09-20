# frozen_string_literal: true

module Poetry
  module Charts
    module TooltipContent
      # The tooltip chrome across its three indicator variants - every
      # chart tooltip composes from exactly these pieces.
      class Preview < Poetry::Core::Preview::Base
        CONFIG = {
          desktop: { label: "Desktop", color: "var(--chart-1)" },
          mobile: { label: "Mobile", color: "var(--chart-2)" }
        }.freeze

        ITEMS = [
          { key: "desktop", value: 1260 },
          { key: "mobile", value: 570 }
        ].freeze

        def default
          render_component(config: CONFIG, items: ITEMS, label: "January")
        end

        def line_indicator
          render_component(config: CONFIG, items: [{ key: "desktop", value: 1260 }],
                           label: "January", indicator: :line)
        end

        def dashed_indicator
          render_component(config: CONFIG, items: [{ key: "desktop", value: 1260 }],
                           label: "January", indicator: :dashed)
        end

        def no_label
          render_component(config: CONFIG, items: ITEMS, hide_label: true)
        end
      end
    end
  end
end
