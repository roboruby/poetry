# frozen_string_literal: true

module Poetry
  module Motion
    module Draggable
      # The draggable's classes: a grab cursor, and no text selection or browser panning mid-drag.
      class Style < Poetry::Core::Style
        base "inline-block cursor-grab touch-none select-none data-dragging:cursor-grabbing"
      end
    end
  end
end
