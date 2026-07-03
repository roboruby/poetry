# frozen_string_literal: true

module Poetry
  module Ui
    module InputOtp
      # The InputOTP dictionary (InputOTP) - slot /
      # container / group / caret strings source-exact from shadcn
      # new-york-v4 input-otp.tsx (validated 2026-07-03); the :input string
      # is poetry's own per the contract dictionary (shadcn delegates it to
      # the input-otp npm lib's inline styles - poetry ships no npm dep).
      #
      # The input hides via opacity/text-transparent/caret-transparent -
      # NEVER sr-only/display:none (it must stay clickable + focusable +
      # AT-visible over the cells at z-20); selection:bg-transparent kills
      # the native highlight under the cells. The container adds relative
      # (the input's inset-0 anchor) to the source string. The fake caret
      # rides the vendored animate-caret-blink keyframe (tw-animate-css
      # layer - verified compiled by the class gate).
      class Style < Poetry::Core::Style
        base "relative flex items-center gap-2 has-disabled:opacity-50"

        # THE control: one real native input, full-length value, stretched
        # invisibly over the slot row.
        element :input, "absolute inset-0 z-20 h-full w-full opacity-[0.005] text-transparent " \
                        "caret-transparent outline-none selection:bg-transparent " \
                        "disabled:cursor-not-allowed"

        element :group, "flex items-center"

        element :slot, "relative flex h-9 w-9 items-center justify-center border-y border-r " \
                       "border-input text-sm shadow-xs transition-all outline-none " \
                       "first:rounded-l-md first:border-l last:rounded-r-md " \
                       "aria-invalid:border-destructive data-[active=true]:z-10 " \
                       "data-[active=true]:border-ring data-[active=true]:ring-[3px] " \
                       "data-[active=true]:ring-ring/50 " \
                       "data-[active=true]:aria-invalid:border-destructive " \
                       "data-[active=true]:aria-invalid:ring-destructive/20 " \
                       "dark:bg-input/30 dark:data-[active=true]:aria-invalid:ring-destructive/40"

        # The fake-caret overlay + the blinking bar (visible only on the
        # active EMPTY cell; steady under prefers-reduced-motion via the
        # utilities layer).
        element :caret, "pointer-events-none absolute inset-0 flex items-center justify-center"

        element :caret_bar, "h-4 w-px animate-caret-blink bg-foreground duration-1000"
      end
    end
  end
end
