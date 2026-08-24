# frozen_string_literal: true

module Poetry
  module Ui
    # A thin divider line between content regions.
    module Separator
      # A thin divider. Decorative by default (aria-hidden;
      # it separates visually but adds nothing for AT). Set decorative: false
      # for a semantic boundary (role=separator with the orientation), e.g.
      # between toolbar groups.
      #
      # @example Horizontal divider between sections
      #   render Poetry::Ui::Separator::Component.new
      class Component < Poetry::Core::Component
        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "A purely visual divider stays decorative (the default): aria-hidden, role absent.",
          "Set decorative: false only when the divide is semantically meaningful (role=separator)."
        ].freeze

        # The divider's axis.
        option :orientation, :symbol, default: :horizontal
        # Whether the divide is purely visual (aria-hidden) or a semantic
        # boundary (role=separator).
        option :decorative, :boolean, default: true

        validates :orientation, inclusion: { in: %i[horizontal vertical] }

        part "separator", "The divider itself - decorative (aria-hidden) by default, " \
                          "role=separator when decorative: false",
             states: {
               "data-orientation" => { condition: "always - the resolved orientation",
                                       values: %w[horizontal vertical] }
             }

        # @api private
        def call
          content_tag(:div, nil, **root_attributes.to_attributes)
        end

        # @api private
        def root_attributes
          attrs = { "data-slot" => "separator", "data-orientation" => orientation }
          if decorative
            attrs["aria-hidden"] = "true"
          else
            attrs["role"] = "separator"
            # ARIA default orientation is horizontal; only mark the exception.
            attrs["aria-orientation"] = "vertical" if orientation == :vertical
          end
          html_attributes.merge_if_not_set(attrs.merge(component_data_attributes))
        end
      end
    end
  end
end
