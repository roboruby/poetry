# frozen_string_literal: true

module Poetry
  module Ui
    module Badge
      # The Badge - shadcn new-york-v4 parity: four variants on semantic
      # tokens, dark destructive at /60 (the composited treatment the
      # contrast gate models). Template-less.
      class Component < Poetry::Core::Component
        VARIANTS = %i[default secondary destructive outline].freeze

        AGENT_RULES = [
          "Badges are non-interactive status labels - never attach click handlers; use Button for actions.",
          "Pick the variant by intent (destructive = error states), never by color preference."
        ].freeze

        style :variant, default: :default, required: true, variants: VARIANTS

        def call
          content_tag(:span, content, **root_attributes.to_attributes)
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "badge", "data-variant" => variant }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
