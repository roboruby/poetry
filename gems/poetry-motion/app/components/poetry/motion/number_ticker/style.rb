# frozen_string_literal: true

module Poetry
  module Motion
    module NumberTicker
      # The ticker's classes: tabular figures, so the count does not jitter.
      class Style < Poetry::Core::Style
        base "inline-block tabular-nums"
        element :reader, "sr-only"
        element :display, "tabular-nums"
      end
    end
  end
end
