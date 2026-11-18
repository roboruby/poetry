# frozen_string_literal: true

module Poetry
  module Island
    module Island
      # The island's classes: a positioned box for the root a fill island
      # paints, and a shell that steps aside once the island is up (the
      # controller marks the island data-island-mounted), keeping its box
      # under a fill island and leaving the flow under a flow one.
      class Style < Poetry::Core::Style
        base "relative"

        element :shell, "block"
        element :shell_fill, "[[data-island-mounted]>&]:invisible"
        element :shell_flow, "[[data-island-mounted]>&]:hidden"
      end
    end
  end
end
