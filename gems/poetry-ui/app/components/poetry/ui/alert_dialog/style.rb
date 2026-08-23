# frozen_string_literal: true

module Poetry
  module Ui
    module AlertDialog
      # Re-expressed through the cn-* theme layer, ported like the
      # parent Dialog: panel chrome + size branches + backdrop + enter
      # animation ride themes/default.css; native-dialog mechanisms and
      # the explicit server-side media/size layout branches stay inline
      # (the source's group/has- gymnastics remain conditionals, not CSS).
      class Style < Poetry::Core::Style
        # open:grid, NOT grid (the Dialog's UA display:none lesson). No
        # `relative`: it is discarded in the top layer (the UA reasserts
        # `absolute`, pinning the panel to the document origin so it scrolls
        # off-screen below the fold); the UA `:modal` rule keeps it fixed and
        # viewport-centered instead. See the parent Dialog.
        element :content, "cn-alert-dialog-content m-auto open:grid"

        element :header, "cn-alert-dialog-header grid grid-rows-[auto_1fr] place-items-center text-center"
        element :header_with_media, "grid-rows-[auto_auto_1fr] gap-x-6"
        # default size: centered on mobile, left from sm (sm size stays
        # centered at every breakpoint - source).
        element :header_size_default, "sm:place-items-start sm:text-left"
        element :header_size_default_with_media, "sm:grid-rows-[auto_1fr]"

        element :media, "cn-alert-dialog-media inline-flex items-center justify-center"
        element :media_size_default, "sm:row-span-2"

        element :title, "cn-alert-dialog-title"
        element :title_beside_media, "sm:col-start-2"

        element :description, "cn-alert-dialog-description"

        # Footer hook is themable (nova bands it); gap-2 moved
        # theme-side with the name - direction/justify stay inline (the
        # sm-size grid branch below replaces them via the class: merge).
        element :footer, "cn-alert-dialog-footer flex flex-col-reverse sm:flex-row sm:justify-end"
        # sm size: the compact 2-col grid footer (source).
        element :footer_size_sm, "grid grid-cols-2"
      end
    end
  end
end
