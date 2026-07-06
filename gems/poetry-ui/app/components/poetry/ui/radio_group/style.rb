# frozen_string_literal: true

module Poetry
  module Ui
    module RadioGroup
      # Re-expressed through the cn-* theme layer (N11): the well + dot
      # treatments ride themes/default.css (the dot keeps its centering
      # mechanics inline). :input stays the hidden native form bridge and
      # :row the demo pairing row - both structural, no cn names.
      class Style < Poetry::Core::Style
        base "cn-radio-group"

        element :item, "cn-radio-group-item aspect-square shrink-0 border outline-none " \
                       "disabled:cursor-not-allowed disabled:opacity-50"

        element :indicator, "relative flex items-center justify-center"

        # The checked dot (source: CircleIcon size-2 fill-primary, centered
        # absolutely inside the indicator).
        element :dot, "cn-radio-group-indicator-icon absolute top-1/2 left-1/2 " \
                      "-translate-x-1/2 -translate-y-1/2"

        # The form participant: one hidden native radio PER item, shared
        # name - out of the Tab order and the accessibility tree (the
        # role=radio button is the accessible control).
        element :input, "sr-only"

        # The item+Label pairing row (radio-group-demo parity) rendered
        # when an item passes label:.
        element :row, "flex items-center gap-3"
      end
    end
  end
end
