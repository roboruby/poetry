# frozen_string_literal: true

module Poetry
  module Motion
    # The behaviors poetry-motion ships ({Poetry::Core::Behavior}).
    module Behaviors
      # The Ruby side of `useDrag` (@poetry/motion/behaviors/drag): an
      # effect's controller runs it, so it declares no wiring of its own,
      # and the registry, llms.txt and the docs list it on every effect
      # that uses it.
      module Drag
        extend Poetry::Core::Behavior

        behavior :drag, "Free dragging with an axis lock and bounds, springing back unless the effect keeps " \
                        "the position.",
                 runtime: true
      end
    end
  end
end
