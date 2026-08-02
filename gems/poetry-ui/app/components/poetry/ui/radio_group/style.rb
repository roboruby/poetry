# frozen_string_literal: true

module Poetry
  module Ui
    module RadioGroup
      # Re-expressed through the cn-* theme layer (N11): the well + dot
      # treatments ride themes/default.css (the dot keeps its centering
      # mechanics inline). :input stays the hidden native form bridge and
      # :row the demo pairing row - both structural, no cn names.
      class Style < Poetry::Core::Style
        base "cn-radio-group"

        element :item, "cn-radio-group-item aspect-square shrink-0 border outline-none " \
                       "disabled:cursor-not-allowed disabled:opacity-50"

        element :indicator, "relative flex items-center justify-center"

        # The checked dot (source: CircleIcon size-2 fill-primary, centered
        # absolutely inside the indicator).
        element :dot, "cn-radio-group-indicator-icon absolute top-1/2 left-1/2 " \
                      "-translate-x-1/2 -translate-y-1/2"

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
