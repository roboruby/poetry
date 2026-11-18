# frozen_string_literal: true

module Poetry
  module Motion
    # The behaviors poetry-motion ships ({Poetry::Core::Behavior}).
    module Behaviors
      # The Ruby side of `useCanvas` (@poetry/motion/behaviors/canvas): an
      # effect's controller runs it, so it declares no wiring of its own,
      # and the registry, llms.txt and the docs list it on every effect
      # that uses it.
      module Canvas
        extend Poetry::Core::Behavior

        behavior :canvas, "A canvas sized to its box at the pixel ratio, drawn every visible frame; one static " \
                          "frame under reduced motion.",
                 runtime: true
      end
    end
  end
end
