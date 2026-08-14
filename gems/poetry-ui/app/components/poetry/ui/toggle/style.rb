# frozen_string_literal: true

module Poetry
  module Ui
    module Toggle
      # Re-expressed through the cn-* theme layer (N11). Still the family's
      # shared dictionary: ToggleGroup items consume it through
      # Toggle::Style.css (shared, never copied). The muted-not-accent
      # hover note now reads off the theme rules: .cn-toggle hovers MUTED
      # (pressed owns accent), .cn-toggle-variant-outline hovers accent -
      # both source-exact, in themes/default.css. hover:bg-muted deviates
      # from upstream's inline split DELIBERATELY: outline's themed accent
      # hover can only beat it from the same layer (the split-side conflict
      # rule - an inline utility would win the cascade unconditionally).
      class Style < Poetry::Core::Style
        base "cn-toggle group/toggle inline-flex items-center justify-center whitespace-nowrap outline-none " \
             "focus-visible:ring-[3px] " \
             "disabled:pointer-events-none disabled:opacity-50 " \
             "[&_svg]:pointer-events-none [&_svg]:shrink-0"

        variant :variant, {
          default: "cn-toggle-variant-default",
          outline: "cn-toggle-variant-outline"
        }

        variant :size, {
          default: "cn-toggle-size-default",
          sm: "cn-toggle-size-sm",
          lg: "cn-toggle-size-lg"
        }
      end
    end
  end
end
