# frozen_string_literal: true

module Poetry
  module Ui
    # The InputGroup family - one bordered field surface for a control plus addons.
    module InputGroup
      # The InputGroup - one bordered field surface holding a control plus
      # addons (icons, text, kbd hints, tiny buttons). The GROUP wears the
      # border and focus ring; the control inside is borderless
      # (poetry_input_group_input / _textarea strip the Input's own chrome
      # and stamp data-slot=input-group-control, which the group's
      # focus-within/invalid selectors key on). Addons align inline
      # (start/end) or block (start/end - full-width rows).
      #
      # @example
      #   <%= poetry_input_group do %>
      #     <%= poetry_input_group_addon do %>
      #       <%= poetry_icon(name: :search) %>
      #     <% end %>
      #     <%= poetry_input_group_input(name: "q", placeholder: "Search...") %>
      #   <% end %>
      class Component < Poetry::Core::Component
        requires_content "its control + addons"

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "The control INSIDE must be poetry_input_group_input/_textarea - a plain poetry_input " \
          "keeps its own border+ring and double-chromes the group.",
          "Addons are poetry_input_group_addon(align:) wrapping icons/text/buttons; use " \
          "poetry_input_group_text for muted captions and poetry_input_group_button for tiny actions.",
          "The group is a surface, not a label - the control still needs its Label/Field pairing."
        ].freeze

        part "input-group", "The bordered group surface (role=group) - wears the border, the " \
                            "focus-within ring, and the invalid ring for the borderless " \
                            "control inside"
        part "input-group-addon", "One addon cell (icons, text, kbd hints, tiny buttons) " \
                                  "rendered by poetry_input_group_addon around the control",
             states: {
               "data-align" => { condition: "always - the addon's align: axis (inline rides " \
                                            "the row, block takes a full-width row)",
                                 values: %w[inline-start inline-end block-start block-end] }
             }

        # Enforces the required content block before render.
        # @api private
        def before_render
          ensure_content!
        end

        # Renders the group surface around the content.
        # @api private
        def call
          content_tag(:div, content, **root_attributes.to_attributes)
        end

        # The group surface's attributes.
        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            { "role" => "group", "data-slot" => "input-group" }.merge(component_data_attributes)
          )
        end

        private :root_attributes
      end
    end
  end
end
