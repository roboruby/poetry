# frozen_string_literal: true

module Poetry
  module Motion
    module Globe
      # The globe's classes: a square, the canvas filling it.
      class Style < Poetry::Core::Style
        base "relative aspect-square w-full max-w-md"
        element :canvas, "size-full"
      end
    end
  end
end
