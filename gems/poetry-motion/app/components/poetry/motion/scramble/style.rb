# frozen_string_literal: true

module Poetry
  module Motion
    module Scramble
      # The scramble's classes: tabular figures keep digits steady.
      class Style < Poetry::Core::Style
        base "inline tabular-nums"
        element :reader, "sr-only"
      end
    end
  end
end
