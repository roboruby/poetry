# frozen_string_literal: true

module Poetry
  module Motion
    module Magnetic
      # The magnetic wrapper's classes: it hugs its control.
      class Style < Poetry::Core::Style
        base "inline-flex"
        element :layer, "inline-flex"
      end
    end
  end
end
