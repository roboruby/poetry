# frozen_string_literal: true

module Poetry
  module Core
    # The behaviors poetry-core ships ({Poetry::Core::Behavior}).
    module Behaviors
      # Anchored positioning (the popper controller): the panel opens on a
      # side of its anchor and flips and shifts to stay in the viewport.
      # Each value is set only when the component passes it: `:option`
      # reads the component's own option, a Hash passes value's from:,
      # if: and unless:, and anything else is a literal. The anchor,
      # content and arrow targets stay on the component's own elements.
      #
      # @example A popover reading its placement options
      #   on(:root) do
      #     behavior :popper, side: :option, align: :option, side_offset: :option,
      #                       align_offset: :option, avoid_collisions: :option
      #   end
      module Popper
        extend Poetry::Core::Behavior

        behavior :popper, "Positions the panel against its anchor and keeps it inside the viewport."

        wiring do |anchor: nil, side: nil, align: nil, side_offset: nil, align_offset: nil, # rubocop:disable Metrics/ParameterLists -- one keyword per popper value
                   avoid_collisions: nil, strategy: nil|
          controller :popper do
            register
            behavior_value :anchor, anchor
            behavior_value :side, side
            behavior_value :align, align
            behavior_value :side_offset, side_offset
            behavior_value :align_offset, align_offset
            behavior_value :avoid_collisions, avoid_collisions
            behavior_value :strategy, strategy
          end
        end
      end
    end
  end
end
