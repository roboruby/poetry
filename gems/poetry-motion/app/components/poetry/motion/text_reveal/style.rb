# frozen_string_literal: true

module Poetry
  module Motion
    module TextReveal
      # The text reveal's classes; the word opacity lives in the motion stylesheet.
      class Style < Poetry::Core::Style
        base "text-balance"
        element :reader, "sr-only"
      end
    end
  end
end
