# frozen_string_literal: true

module Poetry
  module Ui
    module SensitiveInput
      # InputGroup + Input + Button wear the chrome (the SearchField
      # composition); the machine's rendering is structural utilities keyed
      # on the root's data-state. The one theme-owned name is the group's
      # OWN focus ring (cn-sensitive-input-group): while masked the group
      # is the focusable button, and every theme keys its input ring on the
      # CONTROL's focus-visible - the group needs each theme's treatment in
      # that theme's own vocabulary (sera underlines, mira rings at 2).
      class Style < Poetry::Core::Style
        base "flex w-full flex-col"

        # group/sensitive powers the mask's hover swap; disabled kills the
        # pointer affordances at the root.
        element :group, "cn-sensitive-input-group group/sensitive relative " \
                        "[[data-state=masked]:not([data-disabled])_&]:cursor-pointer " \
                        "[[data-disabled]_&]:pointer-events-none"

        # The real input goes transparent (not hidden - it defines the
        # width) and inert while masked.
        element :input, "[[data-state=masked]_&]:pointer-events-none " \
                        "[[data-state=masked]_&]:text-transparent " \
                        "[[data-state=masked]_&]:select-none"

        # The overlay paints the masked state only - and while masked it IS
        # the reveal button (pointer target + focusable); display:none in
        # every other state keeps it out of the a11y tree. Both texts render
        # stacked so the hover swap never shifts layout.
        element :mask, "pointer-events-none absolute inset-y-0 start-0 hidden items-center " \
                       "px-3 text-base outline-none md:text-sm [[data-state=masked]_&]:flex " \
                       "[[data-state=masked]:not([data-disabled])_&]:pointer-events-auto " \
                       "[[data-state=masked]:not([data-disabled])_&]:cursor-pointer"
        element :mask_dots, "group-focus-within/sensitive:invisible group-hover/sensitive:invisible"
        element :mask_reveal, "invisible absolute start-0 top-0 whitespace-nowrap " \
                              "text-muted-foreground group-focus-within/sensitive:visible " \
                              "group-hover/sensitive:visible"

        element :icon_stack, "relative flex size-4 items-center justify-center"
        element :icon_copy, "absolute inset-0 transition-all duration-200 " \
                            "[[data-copied]_&]:scale-0 [[data-copied]_&]:opacity-0"
        element :icon_check, "absolute inset-0 scale-0 opacity-0 transition-all duration-200 " \
                             "[[data-copied]_&]:scale-100 [[data-copied]_&]:opacity-100"
      end
    end
  end
end
