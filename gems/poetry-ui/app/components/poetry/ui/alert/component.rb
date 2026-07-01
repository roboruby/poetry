# frozen_string_literal: true

module Poetry
  module Ui
    module Alert
      # The Alert - shadcn new-york-v4 parity plus the a11y the reference
      # lacks (the vcplus Alert's missing role/aria-live is the original
      # motivating bug). The M6 politeness lock: destructive announces
      # assertively (role=alert); default is polite (role=status).
      class Component < Poetry::Core::Component
        VARIANTS = %i[default destructive].freeze

        AGENT_RULES = [
          "Use poetry_alert for inline callouts - it carries role/aria-live; never a hand-rolled div.",
          "destructive announces assertively (role=alert) - reserve it for errors, not emphasis."
        ].freeze

        style :variant, default: :default, required: true, variants: VARIANTS

        # Typed slot: with_icon(name: :"triangle-alert") - agents pass icon
        # props, never a render block.
        renders_one :icon, Poetry::Ui::Icon::Component
        renders_one :title

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
