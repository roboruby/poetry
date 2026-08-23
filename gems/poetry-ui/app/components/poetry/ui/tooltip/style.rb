# frozen_string_literal: true

module Poetry
  module Ui
    module Tooltip
      # Re-expressed through the cn-* theme layer. The inverse scheme
      # (bg-foreground/text-background) stays INLINE per upstream's own
      # split - it IS the treatment and upstream keeps it in markup; the
      # box, type, and animation chain ride the theme (animate-in remains
      # UNGATED there, source-exact).
      class Style < Poetry::Core::Style
        element :content, "cn-tooltip-content z-50 w-fit " \
                          "origin-(--transform-origin) " \
                          "bg-foreground text-background"

        # The arrow: popper positions/rotates the outer box; the visual
        # size/rounding rides the theme, the paint + geometry stay inline.
        # block: the diamond is a bare span - inline boxes IGNORE size-2.5,
        # which left the arrow 0x0 (invisible) in every theme since the port.
        element :arrow, "cn-tooltip-arrow z-50 block translate-y-[calc(-50%_-_2px)] rotate-45 " \
                        "bg-foreground fill-foreground"
      end
    end
  end
end
