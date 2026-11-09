# frozen_string_literal: true

module Poetry
  module Motion
    module SpotlightCard
      # The spotlight card's classes; the glow lives in the motion stylesheet.
      class Style < Poetry::Core::Style
        base "relative isolate block overflow-hidden rounded-xl"
      end
    end
  end
end
