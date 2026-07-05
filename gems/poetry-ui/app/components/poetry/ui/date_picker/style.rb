# frozen_string_literal: true

module Poetry
  module Ui
    module DatePicker
      # The DatePicker is composition (Popover + Calendar); it owns no
      # visual of its own beyond the trigger's field shape, which the
      # component sets inline on the Button. This dictionary exists so the
      # component participates in the registry/verify machinery; the root is
      # an inline-block wrapper.
      class Style < Poetry::Core::Style
        base "inline-block"
      end
    end
  end
end
