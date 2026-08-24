# frozen_string_literal: true

module Poetry
  module Ui
    # The InputGroup-chrome field kit: what the affix-field controls
    # (NumberField, SearchField, SensitiveInput; the segmented date/time
    # fields share the id ladder) re-typed around InputGroup's chrome -
    # the control-id ladder, the bordered group shell, the addon cells,
    # and the ghost tool-button recipe. The visible-input skeletons stay
    # per family: their attribute sets genuinely differ.
    module InputGroupField
      include FamilyIdentity

      # The control-id ladder: a caller id wins, else the family
      # instance seed.
      def control_id
        @control_id ||= id.presence || instance_id
      end

      def group_attributes
        {
          "role" => "group",
          "data-slot" => "#{family_slot_prefix}-group",
          "class" => InputGroup::Style.css
        }
      end

      def addon_attributes(align)
        {
          "data-slot" => "input-group-addon",
          "data-align" => "inline-#{align}",
          "class" => InputGroup::Style.css(:addon, class: InputGroup::Style.css(:"addon_inline_#{align}"))
        }
      end

      private

      # The ghost icon-xs tool button riding the group chrome (steppers,
      # clear, reveal, copy). tabindex -1 by default (keyboard users act
      # on the control); nil drops it (SensitiveInput's copy is a real
      # tab stop).
      def group_tool_button(slot:, label:, wiring:, tabindex: "-1", extra: {})
        Button::Component.new({
          variant: :ghost, size: :"icon-xs", disabled: disabled, label: label,
          class: InputGroup::Style.css(:button, class: InputGroup::Style.css(:button_icon_xs)),
          "data-slot" => slot,
          "tabindex" => tabindex,
          **extra,
          "aria-controls" => control_id
        }.compact.merge(wiring))
      end
    end
  end
end
