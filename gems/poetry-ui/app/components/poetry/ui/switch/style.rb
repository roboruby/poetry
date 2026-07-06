# frozen_string_literal: true

module Poetry
  module Ui
    module Switch
      # Re-expressed through the cn-* theme layer (N11). The thumb's travel
      # (data-checked translate + poetry's rtl: fix) moves to the theme
      # rule - upstream's own base-registry split does exactly this ("thumb
      # translate moved to theme"). The size axis still travels by data
      # attribute; :input stays the sr-only form store.
      class Style < Poetry::Core::Style
        base "cn-switch peer group/switch inline-flex items-center transition-all outline-none " \
             "disabled:cursor-not-allowed disabled:opacity-50"

        element :thumb, "cn-switch-thumb pointer-events-none block ring-0 transition-transform"

        # The form participant + the store (the Checkbox architecture).
        element :input, "sr-only"
      end
    end
  end
end
