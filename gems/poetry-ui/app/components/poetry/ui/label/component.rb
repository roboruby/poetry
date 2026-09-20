# frozen_string_literal: true

module Poetry
  module Ui
    # A caption for a form control.
    module Label
      # A <label> for a form control, wired to it via for_id:. The
      # caption is the content block.
      #
      # Omit for_id: when the label names a GROUP of controls rather
      # than one element: a for= pointing at a non-control is inert, so
      # in group mode the group names itself via aria-labelledby at this
      # label's id instead.
      #
      # @example A label wired to its control
      #   render Poetry::Ui::Label::Component.new(for_id: "email").with_content("Email")
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Every control gets a Label wired via for_id - placeholder text is never the label."
        ].freeze

        option :for_id, :string,
               doc: "The id of the control this label names; omit it for a group label (the group then points at " \
                    "this label via aria-labelledby)."

        part "label", "The <label> element itself - for= rides it (dropped in group mode, " \
                      "where the group names itself via aria-labelledby at this label's id)"

        # Renders the label around its content.
        # @api private
        def call
          content_tag(:label, content, **root_attributes)
        end

        # The root's attributes: this component's markup over the core default.
        def root_attributes
          attrs = {}
          attrs["for"] = for_id if for_id.present?
          super(attrs)
        end
      end
    end
  end
end
