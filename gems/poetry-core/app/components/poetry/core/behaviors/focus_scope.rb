# frozen_string_literal: true

module Poetry
  module Core
    # The behaviors poetry-core ships ({Poetry::Core::Behavior}).
    module Behaviors
      # Focus held inside an open layer (the focus-scope controller):
      # focus moves in when the layer opens, Tab stays inside a modal one,
      # and focus returns to the trigger on close. The component's
      # controller activates it when the layer opens.
      module FocusScope
        extend Poetry::Core::Behavior

        behavior :focus_scope, "Focus moves into the open layer, stays inside a modal one and returns on close.",
                 runtime: true
      end
    end
  end
end
