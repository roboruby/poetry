# frozen_string_literal: true

module Poetry
  module Motion
    module WordRotate
      # The word rotate's classes; the turn lives in the motion stylesheet.
      class Style < Poetry::Core::Style
        base "inline-grid align-bottom"
        element :reader, "sr-only"
        element :stack, "grid overflow-hidden"
        element :word, "[grid-area:1/1]"
      end
    end
  end
end
