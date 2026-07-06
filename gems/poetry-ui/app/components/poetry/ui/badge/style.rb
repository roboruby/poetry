# frozen_string_literal: true

module Poetry
  module Ui
    module Badge
      # Re-expressed through the cn-* theme layer (N11). Unlike Button,
      # upstream keeps the focus-visible ring + aria-invalid treatments
      # INLINE for Badge - the split is copied faithfully, not re-derived.
      class Style < Poetry::Core::Style
        base "cn-badge inline-flex w-fit shrink-0 items-center justify-center overflow-hidden " \
             "whitespace-nowrap " \
             "focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
             "aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 " \
             "[&>svg]:pointer-events-none"

        variant :variant, {
          default: "cn-badge-variant-default",
          secondary: "cn-badge-variant-secondary",
          destructive: "cn-badge-variant-destructive",
          outline: "cn-badge-variant-outline"
        }
      end
    end
  end
end
