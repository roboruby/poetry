# frozen_string_literal: true

module Poetry
  module Motion
    module Draggable
      # Draggable preview: a card to pick up.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component do
            tag.div("Drag me", class: "rounded-xl border bg-card px-6 py-4 text-sm font-medium shadow-sm")
          end
        end
      end
    end
  end
end
