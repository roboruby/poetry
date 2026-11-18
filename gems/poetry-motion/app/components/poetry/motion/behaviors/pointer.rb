# frozen_string_literal: true

module Poetry
  module Motion
    # The behaviors poetry-motion ships ({Poetry::Core::Behavior}).
    module Behaviors
      # The Ruby side of `usePointer` (@poetry/motion/behaviors/pointer): an
      # effect's controller runs it, so it declares no wiring of its own,
      # and the registry, llms.txt and the docs list it on every effect
      # that uses it.
      module Pointer
        extend Poetry::Core::Behavior

        behavior :pointer, "The pointer's position over the element, once a frame; fine pointers only, inert " \
                           "under reduced motion.",
                 runtime: true

        agent_rule "Pointer effects never move focus and never carry information a keyboard user would " \
                   "miss."
      end
    end
  end
end
