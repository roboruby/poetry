# frozen_string_literal: true

module Poetry
  module Motion
    module Background
      # The background's classes; the patterns and effects live in the motion stylesheet.
      class Style < Poetry::Core::Style
        base "relative isolate overflow-hidden"
        element :layer, "pointer-events-none absolute inset-0 -z-10"
        element :content, "relative"
      end
    end
  end
end
