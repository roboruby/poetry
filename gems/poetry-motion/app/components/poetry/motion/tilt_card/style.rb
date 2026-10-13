# frozen_string_literal: true

module Poetry
  module Motion
    module TiltCard
      # The tilt card's classes; the rotation lives in the motion stylesheet.
      class Style < Poetry::Core::Style
        base "block"
        element :layer, "block"
      end
    end
  end
end
