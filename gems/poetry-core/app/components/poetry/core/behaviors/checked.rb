# frozen_string_literal: true

module Poetry
  module Core
    # The behaviors poetry-core ships ({Poetry::Core::Behavior}).
    module Behaviors
      # A two-state control (the checked controller): a click toggles the
      # checked state, and a form participant mirrors it into its hidden
      # input. The using component defines `form_participant?`.
      #
      # @example Checkbox
      #   on(:root) { behavior :checked }
      module Checked
        extend Poetry::Core::Behavior

        behavior :checked, "A click toggles the checked state and keeps the form input in step."

        wiring do
          controller :checked do
            register
            value :input_id, if: :form_participant?
            action :toggle, on: :click
          end
        end
      end
    end
  end
end
