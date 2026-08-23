# frozen_string_literal: true

module Poetry
  module Ui
    module Alert
      # An inline callout - shadcn new-york-v4 parity plus the a11y the
      # reference lacks: the role/aria-live wiring is built in. The
      # politeness lock: destructive announces assertively (role=alert);
      # default is polite (role=status).
      #
      # @example Destructive alert with a title
      #   render Poetry::Ui::Alert::Component.new(variant: :destructive) do |alert|
      #     alert.with_title { "Payment failed" }
      #     "Your card was declined. Update your billing details."
      #   end
      class Component < Poetry::Core::Component
        VARIANTS = %i[default destructive].freeze

        AGENT_RULES = [
          "Use poetry_alert for inline callouts - it carries role/aria-live; never a hand-rolled div.",
          "destructive announces assertively (role=alert) - reserve it for errors, not emphasis."
        ].freeze

        # Typed slot: with_icon(name: :"triangle-alert") - agents pass icon
        # props, never a render block.
        renders_one :icon, Poetry::Ui::Icon::Component
        renders_one :title
        renders_one :action

        style :variant, default: :default, required: true, variants: VARIANTS

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

        def root_attributes
          html_attributes.merge_if_not_set(
            {
              "data-slot" => "alert",
              "data-variant" => variant,
              "role" => (variant == :destructive ? "alert" : "status")
            }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
