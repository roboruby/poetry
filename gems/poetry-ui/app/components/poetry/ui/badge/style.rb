# frozen_string_literal: true

module Poetry
  module Ui
    module Badge
      # Re-expressed through the cn-* theme layer (N11). The focus/invalid
      # ring chain deviates from upstream's inline split DELIBERATELY: the
      # destructive variant re-colors focus-visible:ring-* in the theme and
      # can only beat the base treatment from the same layer (the
      # split-side conflict rule).
      class Style < Poetry::Core::Style
        base "cn-badge inline-flex w-fit shrink-0 items-center justify-center overflow-hidden " \
             "whitespace-nowrap [&>svg]:pointer-events-none"

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
