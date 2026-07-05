# frozen_string_literal: true

module Poetry
  module Charts
    module TooltipLayer
      # The floating box: absolute within the relative Container, above the
      # SVG, never intercepting the pointer (the SVG owns the events).
      class Style < Poetry::Core::Style
        base "pointer-events-none absolute z-10 w-max"
      end
    end
  end
end
