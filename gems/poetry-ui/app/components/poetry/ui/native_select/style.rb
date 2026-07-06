# frozen_string_literal: true

module Poetry
  module Ui
    module NativeSelect
      # Re-expressed through the cn-* theme layer (N11). appearance-none
      # stays inline as a mechanism guard (a swapped theme must never
      # resurrect the double native arrow); the wrapper and the
      # option/optgroup Canvas system-color guards are structural, no cn
      # names. The chevron wrapper keeps position mechanics inline.
      class Style < Poetry::Core::Style
        base "relative w-fit has-[select:disabled]:opacity-50"

        element :select, "cn-native-select w-full appearance-none outline-none " \
                         "disabled:pointer-events-none disabled:cursor-not-allowed"
        element :icon, "cn-native-select-icon pointer-events-none absolute select-none"
        element :option, "bg-[Canvas] text-[CanvasText]"
        element :optgroup, "bg-[Canvas] text-[CanvasText]"
      end
    end
  end
end
