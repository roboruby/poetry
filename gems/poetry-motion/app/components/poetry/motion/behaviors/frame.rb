# frozen_string_literal: true

module Poetry
  module Motion
    # The behaviors poetry-motion ships ({Poetry::Core::Behavior}).
    module Behaviors
      # The Ruby side of `useFrame` (@poetry/motion/behaviors/frame): an
      # effect's controller runs it, so it declares no wiring of its own,
      # and the registry, llms.txt and the docs list it on every effect
      # that uses it.
      module Frame
        extend Poetry::Core::Behavior

        behavior :frame, "A callback every frame, paused off screen and in hidden tabs; never runs under " \
                         "reduced motion.",
                 runtime: true
      end
    end
  end
end
