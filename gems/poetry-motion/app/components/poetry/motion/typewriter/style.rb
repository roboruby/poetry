# frozen_string_literal: true

module Poetry
  module Motion
    module Typewriter
      # The typewriter's classes; the caret lives in the motion stylesheet.
      class Style < Poetry::Core::Style
        base "inline"
        element :reader, "sr-only"
      end
    end
  end
end
