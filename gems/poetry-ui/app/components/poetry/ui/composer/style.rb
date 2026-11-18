# frozen_string_literal: true

module Poetry
  module Ui
    module Composer
      # Utility-only: InputGroup, Textarea and Button wear the chrome, so
      # the composer adds no theme CSS. What is here is mechanics: the
      # field's one-row floor and its growth ceiling (past it the field
      # scrolls), the action slot's place at the end of the footer row, and
      # the Send button's dimming while the field is empty. With
      # attachments: the field surface's tint while files are dragged over
      # the composer (the controllers' data-dragging / data-drag-reject on
      # the ROOT), the chips' wrapping row, and the rejections under the
      # surface.
      class Style < Poetry::Core::Style
        # relative: a menu is placed against the composer, over it.
        base "group/composer relative w-full min-w-0"

        # A refused drag is also a drag, so its tint names both states:
        # the longer selector wins whichever rule the build emits last.
        element :group, "group-data-[dragging]/composer:border-primary " \
                        "group-data-[dragging]/composer:bg-accent/40 " \
                        "group-data-[dragging]/composer:group-data-[drag-reject]/composer:border-destructive " \
                        "group-data-[dragging]/composer:group-data-[drag-reject]/composer:bg-destructive/10"

        # The chips: one Attachment per file, wrapping, each held to a
        # width so a long name truncates instead of filling the row.
        element :attachments, "flex-wrap gap-1.5 empty:hidden *:data-[slot=attachment]:max-w-60"

        element :errors, "mt-1.5 flex flex-col gap-1 px-1 text-sm text-destructive empty:hidden"

        # A menu: the Combobox popup's chrome, set over the composer at
        # its full width. Its list scrolls past a ceiling; an option's
        # description is pushed to the end of its row and gives way first.
        element :menu, "cn-combobox-content cn-menu-translucent absolute inset-x-0 bottom-full z-50 mb-1.5 " \
                       "outline-hidden"
        element :menu_list, "max-h-60"
        # A server-fed list is a Turbo frame, an inline box until told otherwise.
        element :menu_frame, "block"
        element :menu_option, "gap-2"
        element :menu_option_label, "min-w-0 truncate"
        element :menu_option_description, "ms-auto min-w-0 shrink truncate ps-2 text-xs text-muted-foreground"

        element :input, "max-h-48 min-h-10"

        element :action, "ms-auto flex shrink-0 items-center gap-1"

        element :send, "group-data-[empty]/composer:opacity-50"
      end
    end
  end
end
