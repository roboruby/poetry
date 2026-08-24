# frozen_string_literal: true

module Poetry
  module Ui
    # Inline callouts for statuses and errors.
    module Alert
      # An inline callout for statuses and errors, with the live-region
      # wiring built in. The default variant announces politely
      # (role=status); :destructive announces assertively (role=alert),
      # so reserve it for genuine errors.
      #
      # @example Destructive alert with a title
      #   render Poetry::Ui::Alert::Component.new(variant: :destructive) do |alert|
      #     alert.with_title { "Payment failed" }
      #     "Your card was declined. Update your billing details."
      #   end
      class Component < Poetry::Core::Component
        # The closed vocabulary for the variant axis.
        VARIANTS = %i[default destructive].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Use poetry_alert for inline callouts - it carries role/aria-live; never a hand-rolled div.",
          "destructive announces assertively (role=alert) - reserve it for errors, not emphasis."
        ].freeze

        slot_doc :icon, "Optional leading icon; pass icon props (e.g. name: :\"triangle-alert\"), not a block."
        renders_one :icon, Poetry::Ui::Icon::Component
        slot_doc :title, "The heading line of the callout."
        renders_one :title
        slot_doc :action, "Optional corner action (a dismiss button or link), pinned to the top-right."
        renders_one :action

        style :variant, default: :default, required: true, variants: VARIANTS,
                        doc: "The intent axis; :destructive marks errors and announces assertively."

        part "alert", "The callout root - role rides the variant (destructive announces " \
                      "assertively via role=alert; default is a polite role=status)",
             states: {
               "data-variant" => { condition: "always - the resolved variant",
                                   values: VARIANTS.map(&:to_s) }
             }
        part "alert-title", "The heading line, rendered when the title slot is set"
        part "alert-action", "The corner action well (with_action) - a dismiss or link " \
                             "pinned to the top-right by the theme"
        part "alert-description", "The body copy - the content block renders here"

        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "alert",
              "data-variant" => variant,
              "role" => (variant == :destructive ? "alert" : "status")
            }.merge(component_data_attributes)
          )
        end

        private :root_attributes
      end
    end
  end
end
