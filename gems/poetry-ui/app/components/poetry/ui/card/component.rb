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
          "The card body is the content block; use CardAction for the header-corner control."
        ].freeze

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
