# frozen_string_literal: true

module Poetry
  module Ui
    module Button
      # The Button dictionary, re-expressed through the cn-* theme layer:
      # entries carry the stable `cn-button*` names plus the
      # structural/behavioral inline set; the visual classes live in
      # themes/default.css. NOTE dark destructive: the dark treatment
      # paints bg-destructive/60 - the composite the contrast gate
      # measures (6.5:1); solid dark destructive is 2.9:1 and must never
      # carry white text undiluted (the rule lives in the theme file's
      # .cn-button-variant-destructive).
      class Style < Poetry::Core::Style
        base "cn-button inline-flex shrink-0 items-center justify-center whitespace-nowrap " \
             "transition-all outline-none disabled:pointer-events-none disabled:opacity-50 " \
             "[&_svg]:pointer-events-none [&_svg]:shrink-0"

        variant :variant, {
          default: "cn-button-variant-default",
          destructive: "cn-button-variant-destructive",
          outline: "cn-button-variant-outline",
          secondary: "cn-button-variant-secondary",
          ghost: "cn-button-variant-ghost",
          link: "cn-button-variant-link"
        }

        variant :size, {
          default: "cn-button-size-default",
          xs: "cn-button-size-xs",
          sm: "cn-button-size-sm",
          lg: "cn-button-size-lg",
          icon: "cn-button-size-icon",
          "icon-xs": "cn-button-size-icon-xs",
          "icon-sm": "cn-button-size-icon-sm",
          "icon-lg": "cn-button-size-icon-lg"
        }
      end
    end
  end
end
