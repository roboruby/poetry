# frozen_string_literal: true

module Poetry
  module Charts
    module LegendContent
      # The legend chrome: config-derived (the default) and explicit items.
      class Preview < Poetry::Core::Preview::Base
        CONFIG = {
          desktop: { label: "Desktop", color: "var(--chart-1)" },
          mobile: { label: "Mobile", color: "var(--chart-2)" }
        }.freeze

        def default
          render_component(config: CONFIG)
        end

        def top_aligned
          render_component(config: CONFIG, align: :top)
        end
      end
    end
  end
end
