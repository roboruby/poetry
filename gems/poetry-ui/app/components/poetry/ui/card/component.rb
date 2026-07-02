# frozen_string_literal: true

module Poetry
  module Ui
    module Card
      # The Card - shadcn new-york-v4 parity via data-slot composition
      # One component whose parts are slots arranged by the template;
      # every part carries its data-slot role, and the header grid reacts
      # to the presence of an action via has-data-[slot=card-action].
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "Compose with the slots (title/description/action/footer) - never rebuild the header grid by hand.",
          "The card body is the content block; use CardAction for the header-corner control.",
          "The title renders as a real heading (h3 default) - set title_tag: to fit the page outline."
        ].freeze

        # A real HEADING (h3 by default) - a deliberate a11y improvement
        # over shadcn's div, caught by the eval harness's heading_semantics
        # gate (2026-07-01). Visual classes unchanged, so parity holds.
        option :title_tag, :symbol, default: :h3

        validates :title_tag, inclusion: { in: %i[h1 h2 h3 h4 h5 h6] }

        renders_one :title
        renders_one :description
        renders_one :action
        renders_one :footer

        def header?
          title? || description? || action?
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "card" }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
