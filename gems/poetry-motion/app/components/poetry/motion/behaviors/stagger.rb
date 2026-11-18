# frozen_string_literal: true

module Poetry
  module Motion
    # The behaviors poetry-motion ships ({Poetry::Core::Behavior}).
    module Behaviors
      # The Ruby side of `useStagger` (@poetry/motion/behaviors/stagger): an
      # effect's controller runs it, so it declares no wiring of its own,
      # and the registry, llms.txt and the docs list it on every effect
      # that uses it.
      module Stagger
        extend Poetry::Core::Behavior

        behavior :stagger, "One animation across a list, each item starting a step after the last.", runtime: true
      end
    end
  end
end
