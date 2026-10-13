# frozen_string_literal: true

module Poetry
  module Motion
    # The behaviors poetry-motion ships ({Poetry::Core::Behavior}).
    module Behaviors
      # The Ruby side of `useGesture` (@poetry/motion/behaviors/gesture): an
      # effect's controller runs it, so it declares no wiring of its own,
      # and the registry, llms.txt and the docs list it on every effect
      # that uses it.
      module Gesture
        extend Poetry::Core::Behavior

        behavior :gesture, "Press, hover and swipe on one element, keyboard presses included.", runtime: true
      end
    end
  end
end
