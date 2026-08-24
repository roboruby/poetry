# frozen_string_literal: true

module Poetry
  module Ui
    # The Fieldset family - a named group of related fields.
    module Fieldset
      # The Fieldset - the Field family's GROUP layer: a run of related
      # fields inside a
      # real <fieldset>, named by a real <legend>. The native pair carries
      # the group semantics assistive technology already understands - no
      # aria wiring to
      # hand-write, which is why legend: is required rather than optional
      # chrome. legend_variant: :label renders the legend at label size
      # while the group keeps its accessible name.
      #
      # @example A named group of address fields
      #   render Poetry::Ui::Fieldset::Component.new(legend: "Shipping address") do
      #     # poetry_field_group with the fields
      #   end
      class Component < Poetry::Core::Component
        # The closed vocabulary for the legend_variant axis.
        LEGEND_VARIANTS = %i[legend label].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "A run of related fields gets poetry_fieldset with legend: - the group's accessible " \
          "name (a bare <div> around fields tells AT nothing).",
          "legend_variant: :label renders the legend at label size - use it when the group is " \
          "one setting explained by its rows (checkbox/switch runs).",
          "hint: is the muted description under the legend; per-field hints stay on the fields.",
          "Stack the fields inside with poetry_field_group - never hand-spaced flex columns."
        ].freeze

        # The group's accessible name - renders as the real <legend>.
        option :legend, :string, required: true
        # :label renders the legend at label size - for a group that is
        # one setting explained by its rows (checkbox/switch runs).
        option :legend_variant, :symbol, default: :legend
        # Muted description under the legend; per-field hints stay on the fields.
        option :hint, :string

        validates :legend_variant, inclusion: { in: LEGEND_VARIANTS }

        part "field-set", "The <fieldset> root - legend, optional hint, then the fields"
        part "field-legend", "The <legend> - the group's accessible name",
             states: {
               "data-variant" => { condition: "always - the legend's size treatment",
                                   values: LEGEND_VARIANTS.map(&:to_s) }
             }
        part "field-set-hint", "Muted description under the legend (hint:)"

        # Enforces the required legend before render.
        # @api private
        def before_render
          raise ArgumentError, "Fieldset requires legend: (the group's accessible name)" if legend.blank?
        end

        # Renders the <fieldset> (legend, optional hint, then the fields).
        # @api private
        def call
          content_tag(:fieldset, **root_attributes.to_attributes) do
            safe_join([legend_tag, hint_tag, content].compact)
          end
        end

        # The <fieldset> root's attributes.
        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "field-set" }.merge(component_data_attributes)
          )
        end

        private

        def legend_tag
          content_tag(:legend, legend, "data-slot" => "field-legend",
                                       "data-variant" => legend_variant,
                                       "class" => css(:legend))
        end

        def hint_tag
          return if hint.blank?

          content_tag(:p, hint, "data-slot" => "field-set-hint", "class" => css(:hint))
        end
      end
    end
  end
end
