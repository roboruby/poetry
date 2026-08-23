# frozen_string_literal: true

module Poetry
  module Ui
    module RadioGroup
      # Re-expressed through the cn-* theme layer: the well + dot
      # treatments ride the themes. The indicator is a theme-SIZED box
      # (upstream's 2026-07 refactor) so the absolutely-centered dot
      # anchors against a real rect regardless of the item's display -
      # an unsized anchor span centers only by flow accident (7px off
      # under nova's flex item). :input stays the hidden native form
      # bridge and :row the demo pairing row - both structural, no cn
      # names.
      class Style < Poetry::Core::Style
        base "cn-radio-group"

        element :item, "cn-radio-group-item group/radio-group-item peer relative aspect-square " \
                       "shrink-0 border outline-none after:absolute after:-inset-x-3 " \
                       "after:-inset-y-2 disabled:cursor-not-allowed disabled:opacity-50"

        element :indicator, "cn-radio-group-indicator"

        # The checked dot - a bare themed span (bg + size + centering all
        # live in the theme's cn-radio-group-indicator-icon rule).
        element :dot, "cn-radio-group-indicator-icon"

        # The form participant: one hidden native radio PER item, shared
        # name - out of the Tab order and the accessibility tree (the
        # role=radio button is the accessible control).
        element :input, "sr-only"

        # The item+Label pairing row (radio-group-demo parity) rendered
        # when an item passes label:.
        element :row, "flex items-center gap-3"

        # The choice-card row (item variant: :card): the card IS the
        # label, wearing the Field family's cn-field-label hooks so one
        # theme rule styles choice cards wherever they appear. Upstream
        # nests FieldLabel > Field > FieldContent; poetry flattens the
        # row onto the label (cn-field-label-card carries the border/
        # padding the nested [data-slot=field] selectors keyed upstream).
        # cn-label rides along because the card is a plain <label>, not
        # the Label component (part-ownership: a nested data-component
        # boundary would hand the card slots to Label).
        element :card, "cn-label cn-field-label cn-field-label-card flex w-full items-center " \
                       "select-none has-data-disabled:opacity-50"
        element :card_content, "cn-field-content group/field-content flex flex-1 flex-col " \
                               "leading-snug"
        element :card_title, "cn-field-title flex w-fit items-center"
        element :card_description, "cn-field-description"
      end
    end
  end
end
