# frozen_string_literal: true

module Poetry
  module Core
    # The behaviors poetry-core ships ({Poetry::Core::Behavior}).
    module Behaviors
      # Arrow-key focus movement across a group's items (the roving-focus
      # controller): Arrow, Home and End move focus, and by default the
      # group is one Tab stop. Each value is set only when the component
      # passes it: `:option` reads the component's own option, anything
      # else is a literal.
      #
      # @example Tabs: the list reads the orientation option and loops
      #   on(:list) { behavior :roving_focus, orientation: :option, loop: true }
      module RovingFocus
        extend Poetry::Core::Behavior

        behavior :roving_focus, "Arrow, Home and End keys move focus across the group's items."

        wiring do |orientation: nil, manage_tabindex: nil, loop: nil|
          controller :roving_focus do
            register
            behavior_value :orientation, orientation
            behavior_value :manage_tabindex, manage_tabindex
            behavior_value :loop, loop
            action :keydown, on: :keydown
          end
        end
      end
    end
  end
end
