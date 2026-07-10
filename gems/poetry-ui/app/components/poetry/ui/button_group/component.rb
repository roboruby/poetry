# frozen_string_literal: true

module Poetry
  module Ui
    module ButtonGroup
      # The ButtonGroup - visually joins adjacent controls (buttons, inputs,
      # select triggers) into one segmented unit: outer corners stay rounded,
      # inner corners and doubled borders collapse. Compose the members in
      # the content block; poetry_button_group_text and
      # poetry_button_group_separator are the non-button parts.
      class Component < Poetry::Core::Component
        ORIENTATIONS = %i[horizontal vertical].freeze

        AGENT_RULES = [
          "Members go in the content block - the group's selectors join ANY data-slot children " \
          "(buttons, inputs, select triggers); never hand-round the inner corners.",
          "Give the group an aria-label when the page has more than one (role=group is unnamed by default).",
          "A visual divider between members is poetry_button_group_separator, not a styled border."
        ].freeze

        style :orientation, default: :horizontal, required: true, variants: ORIENTATIONS

        requires_content "its member controls"

        def before_render
          ensure_content!
        end

        def call
          content_tag(:div, content, **root_attributes.to_attributes)
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "role" => "group", "data-slot" => "button-group",
              "data-orientation" => orientation
            }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
