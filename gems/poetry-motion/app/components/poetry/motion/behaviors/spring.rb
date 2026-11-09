# frozen_string_literal: true

module Poetry
  module Motion
    # The behaviors poetry-motion ships ({Poetry::Core::Behavior}).
    module Behaviors
      # The Ruby side of `useSpring` (@poetry/motion/behaviors/spring): an
      # effect's controller runs it, so it declares no wiring of its own,
      # and the registry, llms.txt and the docs list it on every effect
      # that uses it.
      module Spring
        extend Poetry::Core::Behavior

        behavior :spring, "A value that springs to each new target and is retargeted without a jump.", runtime: true
      end
    end
  end
end
