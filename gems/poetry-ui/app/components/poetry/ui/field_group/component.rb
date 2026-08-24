# frozen_string_literal: true

module Poetry
  module Ui
    # The FieldGroup family - the stacking container for Fields.
    module FieldGroup
      # The FieldGroup - the Field family's stacking container: fields,
      # fieldsets, and separators stack with the
      # theme's rhythm instead of hand-spaced flex columns. It is also the
      # CSS `@container` scope responsive fields key on - Field's
      # orientation: :responsive flips to a row only once ITS field-group
      # container passes the md mark.
      #
      # @example Stacking fields with the theme's rhythm
      #   render Poetry::Ui::FieldGroup::Component.new do
      #     safe_join([
      #       render(Poetry::Ui::Field::Component.new) { ... },
      #       render(Poetry::Ui::FieldSeparator::Component.new),
      #       render(Poetry::Ui::Field::Component.new) { ... }
      #     ])
      #   end
      class Component < Poetry::Core::Component
        # The closed vocabulary for the variant axis.
        VARIANTS = %i[default choices].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Stack Fields (and Fieldsets) with poetry_field_group - the theme owns the rhythm; " \
          "never hand-space a form column with gap utilities.",
          "variant: :choices packs a run of horizontal checkbox/switch fields tighter (the " \
          "upstream checkbox-group form).",
          "Field's orientation: :responsive is container-driven: it needs a FieldGroup " \
          "ancestor to measure against - without one it stays stacked."
        ].freeze

        # :choices packs a run of horizontal checkbox/switch fields tighter.
        style :variant, default: :default, required: true, variants: VARIANTS

        part "field-group", "The stacking container - fields, fieldsets, and separators " \
                            "render as direct children; also the @container responsive " \
                            "fields measure against"

        # Renders the stacking container around the content.
        # @api private
        def call
          content_tag(:div, content, **root_attributes.to_attributes)
        end

        # The container's attributes.
        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "field-group" }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
