# frozen_string_literal: true

module Poetry
  module Core
    # The behaviors poetry-core ships ({Poetry::Core::Behavior}).
    module Behaviors
      # Dismissal of an open layer (the dismissable controller): Escape
      # and a press outside close it, the topmost layer first. The
      # component's controller activates it when the layer opens, so no
      # preview renders it and the JS suite proves it.
      module Dismissable
        extend Poetry::Core::Behavior

        behavior :dismissable, "Escape or a press outside closes the open layer, the topmost first.", runtime: true
      end
    end
  end
end
