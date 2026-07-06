# frozen_string_literal: true

module Poetry
  module Ui
    module Tooltip
      # Re-expressed through the cn-* theme layer (N11). The inverse scheme
      # (bg-foreground/text-background) stays INLINE per upstream's own
      # split - it IS the treatment and upstream keeps it in markup; the
      # box, type, and animation chain ride the theme (animate-in remains
      # UNGATED there, source-exact).
      class Style < Poetry::Core::Style
        element :content, "cn-tooltip-content z-50 w-fit " \
                          "origin-(--radix-tooltip-content-transform-origin) " \
                          "bg-foreground text-background"

        # The arrow: popper positions/rotates the outer box; the visual
        # size/rounding rides the theme, the paint + geometry stay inline.
        element :arrow, "cn-tooltip-arrow z-50 translate-y-[calc(-50%_-_2px)] rotate-45 " \
                        "bg-foreground fill-foreground"
      end
    end
  end
end
