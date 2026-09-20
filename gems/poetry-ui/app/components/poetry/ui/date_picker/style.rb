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

        # The trigger Button's classes (dictionary-resident so safelists
        # ship them - a bare Ruby string compiles in no host). Range
        # triggers run wider (two dates + the dash; upstream sizes its
        # range demo up the same way).
        element :trigger_single, "w-56"
        element :trigger_range, "w-72"
        element :trigger_chrome, "justify-start font-normal"
        element :trigger_placeholder, "text-muted-foreground"
      end
    end
  end
end
