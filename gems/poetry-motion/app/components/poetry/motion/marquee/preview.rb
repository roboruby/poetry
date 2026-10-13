# frozen_string_literal: true

module Poetry
  module Motion
    module Marquee
      # Marquee previews: the default row, the vertical column and the paused loop.
      class Preview < Poetry::Core::Preview::Base
        ITEMS = %w[Acme Globex Initech Umbrella Hooli Vandelay].freeze

        def default
          render_component(label: "Our customers") { items }
        end

        def vertical
          render_component(label: "Testimonials", direction: :up, duration: 30, class: "h-48") { items }
        end

        def right_and_slow
          render_component(label: "Partners", direction: :right, duration: 80, repeat: 3) { items }
        end

        private

        def items
          safe_join(ITEMS.map { |name| tag.span(name, class: "px-6 text-lg font-semibold text-muted-foreground") })
        end
      end
    end
  end
end
