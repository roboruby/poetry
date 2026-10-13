# frozen_string_literal: true

module Poetry
  module Motion
    module Confetti
      # The confetti's classes: the canvas covers the viewport and lets every pointer through.
      class Style < Poetry::Core::Style
        base "inline-flex"
        element :canvas, "pointer-events-none fixed inset-0 z-50 size-full"
      end
    end
  end
end
