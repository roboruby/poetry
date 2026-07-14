# frozen_string_literal: true

module Poetry
  module Ui
    module SearchField
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(name: "q", label: "Search", placeholder: "Search…")
        end

        # Non-empty: the clear affordance shows; Escape clears once, the
        # next Escape reaches the dismissal layer.
        def with_value
          render_component(name: "q", label: "Search", value: "design tokens")
        end

        def disabled
          render_component(name: "q", label: "Search", value: "locked", disabled: true)
        end
      end
    end
  end
end
