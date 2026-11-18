# frozen_string_literal: true

module Poetry
  module Motion
    # The behaviors poetry-motion ships ({Poetry::Core::Behavior}).
    module Behaviors
      # The Ruby side of `useScrollValue` (@poetry/motion/behaviors/scroll_value): an
      # effect's controller runs it, so it declares no wiring of its own,
      # and the registry, llms.txt and the docs list it on every effect
      # that uses it.
      module ScrollValue
        extend Poetry::Core::Behavior

        behavior :scroll_value, "Progress from 0 to 1 tied to scrolling; the finished state under reduced motion.",
                 runtime: true
      end
    end
  end
end
