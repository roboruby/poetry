# frozen_string_literal: true

module Poetry
  module Motion
    # The behaviors poetry-motion ships ({Poetry::Core::Behavior}).
    module Behaviors
      # The Ruby side of `useAnimate` (@poetry/motion/behaviors/animate): an
      # effect's controller runs it, so it declares no wiring of its own,
      # and the registry, llms.txt and the docs list it on every effect
      # that uses it.
      module Animate
        extend Poetry::Core::Behavior

        behavior :animate, "One engine animation toward the element's server-rendered style; skipped under " \
                           "reduced motion and on return visits.",
                 runtime: true

        agent_rule "Effects are decoration; the server-rendered content stands alone and reads right " \
                   "with motion off."
        agent_rule "No spring, pointer input, scroll link or interruption means a CSS keyframe, not " \
                   "poetry-motion."
        agent_rule "Animate toward the server-rendered state: the last keyframe is the element's own " \
                   "style."
      end
    end
  end
end
