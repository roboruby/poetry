# frozen_string_literal: true

module Poetry
  module Ui
    # Segmented groups of adjacent controls.
    module ButtonGroup
      # Visually joins adjacent controls (buttons, inputs, select
      # triggers) into one segmented unit: outer corners stay rounded,
      # inner corners and doubled borders collapse. Compose the members in
      # the content block; poetry_button_group_text and
      # poetry_button_group_separator are the non-button parts.
      #
      # @example A segmented pair
      #   render Poetry::Ui::ButtonGroup::Component.new("aria-label": "Alignment") do
      #     safe_join([
      #       render(Poetry::Ui::Button::Component.new(variant: :outline).with_content("Left")),
      #       render(Poetry::Ui::Button::Component.new(variant: :outline).with_content("Right"))
      #     ])
      #   end
      class Component < Poetry::Core::Component
        requires_content "its member controls"

        # The closed vocabulary for the orientation axis.
        ORIENTATIONS = %i[horizontal vertical].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Members go in the content block - the group's selectors join ANY data-slot children " \
          "(buttons, inputs, select triggers); never hand-round the inner corners.",
          "Give the group an aria-label when the page has more than one (role=group is unnamed by default).",
          "A visual divider between members is poetry_button_group_separator, not a styled border."
        ].freeze

        # The join axis - a horizontal row or a vertical stack.
        style :orientation, default: :horizontal, required: true, variants: ORIENTATIONS

        part "button-group", "The role=group root - its selectors join ANY data-slot children into " \
                             "the segmented unit",
             states: {
               "data-orientation" => { condition: "the join axis", values: ORIENTATIONS.map(&:to_s) }
             }
        part "button-group-text", "A non-button member (the poetry_button_group_text helper's div) - " \
                                  "a text affix joined like a button"

        # Enforces the member-controls content block.
        # @api private
        def before_render
          ensure_content!
        end

        # @api private
        def call
          content_tag(:div, content, **root_attributes.to_attributes)
        end

        # @api private
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
