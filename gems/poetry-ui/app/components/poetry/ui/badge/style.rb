# frozen_string_literal: true

module Poetry
  module Ui
    module Badge
      # Re-expressed through the cn-* theme layer. The focus/invalid
      # ring chain deviates from upstream's inline split DELIBERATELY: the
      # destructive variant re-colors focus-visible:ring-* in the theme and
      # can only beat the base treatment from the same layer (the
      # split-side conflict rule).
      class Style < Poetry::Core::Style
        base "cn-badge inline-flex w-fit shrink-0 items-center justify-center overflow-hidden " \
             "whitespace-nowrap [&>svg]:pointer-events-none aria-invalid:border-destructive " \
             "aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 " \
             "focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 " \
             "group/badge"

        # success/warning/info: the poetry-original soft status vocabulary
        # (upstream Badge has no status variants); every theme carries the
        # soft treatment on the new status tokens.
        variant :variant, {
          ghost: "cn-badge-variant-ghost",
          link: "cn-badge-variant-link",
          default: "cn-badge-variant-default",
          secondary: "cn-badge-variant-secondary",
          destructive: "cn-badge-variant-destructive",
          outline: "cn-badge-variant-outline",
          success: "cn-badge-variant-success",
          warning: "cn-badge-variant-warning",
          info: "cn-badge-variant-info"
        }
      end
    end
  end
end
