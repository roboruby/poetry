# frozen_string_literal: true

module Poetry
  module Motion
    module Particles
      # The particles' classes: a canvas filling the region behind the content.
      class Style < Poetry::Core::Style
        base "relative isolate overflow-hidden"
        element :canvas, "pointer-events-none absolute inset-0 -z-10 size-full"
        element :content, "relative"
      end
    end
  end
end
