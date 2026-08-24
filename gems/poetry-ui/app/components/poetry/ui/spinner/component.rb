# frozen_string_literal: true

module Poetry
  module Ui
    # A spinning loader glyph that announces itself to assistive tech.
    module Spinner
      # A spinning loader glyph that announces itself (role=status +
      # aria-label). Renders the loader-circle glyph as its own svg (so
      # the root carries the spinner identity, not the icon's).
      #
      # @example
      #   render Poetry::Ui::Spinner::Component.new(label: "Saving...")
      class Component < Poetry::Core::Component
        # The icon-set glyph the spinner renders.
        GLYPH = :"loader-circle"
        # The svg root's fixed attributes (icon-standard 24px viewBox).
        SVG_BOX = {
          "xmlns" => "http://www.w3.org/2000/svg", "width" => "24", "height" => "24",
          "viewBox" => "0 0 24 24", "fill" => "none", "stroke" => "currentColor",
          "stroke-width" => "2", "stroke-linecap" => "round", "stroke-linejoin" => "round"
        }.freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Spinner announces itself (role=status + aria-label) - never a bare spinning div.",
          "Set label: for the loading context ('Saving…'); the default is 'Loading'."
        ].freeze

        # What assistive tech announces - name the loading context.
        option :label, :string, default: "Loading"

        part "spinner", "The spinning <svg> itself (the lucide loader-circle) - announces " \
                        "as role=status with aria-label from label:"

        # @api private
        def call
          content_tag(:svg, glyph, **root_attributes.to_attributes)
        end

        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            SVG_BOX.merge(
              "data-slot" => "spinner", "role" => "status", "aria-label" => label
            ).merge(component_data_attributes)
          )
        end

        private

        def glyph
          Poetry::Core::Icons.set(nil).fetch(GLYPH).html_safe
        end
      end
    end
  end
end
