# frozen_string_literal: true

module Poetry
  module Ui
    module InputGroup
      # The InputGroup - one bordered field surface holding a control plus
      # addons (icons, text, kbd hints, tiny buttons). The GROUP wears the
      # border and focus ring; the control inside is borderless
      # (poetry_input_group_input / _textarea strip the Input's own chrome
      # and stamp data-slot=input-group-control, which the group's
      # focus-within/invalid selectors key on). Addons align inline
      # (start/end) or block (start/end - full-width rows).
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "The control INSIDE must be poetry_input_group_input/_textarea - a plain poetry_input " \
          "keeps its own border+ring and double-chromes the group.",
          "Addons are poetry_input_group_addon(align:) wrapping icons/text/buttons; use " \
          "poetry_input_group_text for muted captions and poetry_input_group_button for tiny actions.",
          "The group is a surface, not a label - the control still needs its Label/Field pairing."
        ].freeze

        requires_content "its control + addons"

        def before_render
          ensure_content!
        end

        def call
          content_tag(:div, content, **root_attributes.to_attributes)
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "role" => "group", "data-slot" => "input-group" }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
