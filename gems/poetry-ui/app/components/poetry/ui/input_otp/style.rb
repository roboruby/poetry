# frozen_string_literal: true

module Poetry
  module Ui
    module InputOtp
      # Re-expressed through the cn-* theme layer. The invisible-
      # control mechanism stays ENTIRELY inline (:input stretched over the
      # slot row at opacity 0.005 - clickable, focusable, AT-visible; NEVER
      # sr-only) as does the caret overlay geometry + blink motion; the
      # cell chrome (borders, active ring, invalid) rides
      # .cn-input-otp-slot in themes/default.css.
      class Style < Poetry::Core::Style
        base "cn-input-otp relative flex items-center has-disabled:opacity-50"

        # THE control: one real native input, full-length value, stretched
        # invisibly over the slot row.
        element :input, "absolute inset-0 z-20 h-full w-full opacity-[0.005] text-transparent " \
                        "caret-transparent outline-none selection:bg-transparent " \
                        "disabled:cursor-not-allowed"

        element :group, "cn-input-otp-group flex items-center"

        element :slot, "cn-input-otp-slot relative flex items-center justify-center " \
                       "data-[active=true]:z-10"

        # The fake-caret overlay + the blinking bar (visible only on the
        # active EMPTY cell; steady under prefers-reduced-motion via the
        # utilities layer).
        element :caret, "pointer-events-none absolute inset-0 flex items-center justify-center"

        element :caret_bar, "cn-input-otp-caret-line animate-caret-blink duration-1000"
      end
    end
  end
end
