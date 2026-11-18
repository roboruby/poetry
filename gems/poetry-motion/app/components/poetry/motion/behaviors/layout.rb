# frozen_string_literal: true

module Poetry
  module Motion
    # The behaviors poetry-motion ships ({Poetry::Core::Behavior}).
    module Behaviors
      # The Ruby side of `useLayout` (@poetry/motion/behaviors/layout): an
      # effect's controller runs it, so it declares no wiring of its own,
      # and the registry, llms.txt and the docs list it on every effect
      # that uses it.
      module Layout
        extend Poetry::Core::Behavior

        behavior :layout, "DOM changes animated as layout transitions, only when no Turbo visit holds the " \
                          "view-transition slot.",
                 runtime: true
      end
    end
  end
end
