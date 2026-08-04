# frozen_string_literal: true

module Poetry
  module Ui
    module Input
      # Re-expressed through the cn-* theme layer (N11): the field chrome
      # (border, ring, invalid, dark treatments) rides themes/default.css.
      # Placeholder color moved theme-side at N12 W2: rhea's tinted field
      # surface (bg-input/50) needs a darkened placeholder to hold AA, and
      # an inline color would beat any theme's (layer order).
      class Style < Poetry::Core::Style
        base "cn-input w-full min-w-0 outline-none " \
             "file:inline-flex file:border-0 file:bg-transparent file:text-foreground " \
             "disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50"
      end
    end
  end
end
