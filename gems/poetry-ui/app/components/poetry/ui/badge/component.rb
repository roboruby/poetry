# frozen_string_literal: true

module Poetry
  module Ui
    # Non-interactive status pills.
    module Badge
      # A small status pill. Variants carry semantic intent: the solid
      # set (default/secondary/destructive/outline/ghost/link) for labels
      # and emphasis, plus the soft status trio (success/warning/info) -
      # the muted color-coded pills record-status columns need.
      #
      # Badges are non-interactive; the one interactive form is href:,
      # which renders the pill as a real link.
      #
      # @example A soft status pill
      #   render Poetry::Ui::Badge::Component.new(variant: :success) { "Fulfilled" }
      class Component < Poetry::Core::Component
        # A status label with no text is an invisible sliver.
        requires_content "the visible status text"

        # The closed vocabulary for the variant axis.
        VARIANTS = %i[default secondary destructive outline ghost link success warning info].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Badges are non-interactive status labels - never attach click handlers; use Button for " \
          "actions. The one interactive form is href:, which renders the badge AS a real link " \
          "(a navigational chip - the themes' [a&]:hover treatments activate).",
          "The visible text is the content block: render ... { \"beta\" } - there is no label: option.",
          "Pick the variant by intent (destructive = error states; success/warning/info = record " \
          "status, e.g. Fulfilled/Processing/Syncing), never by color preference.",
          "Status badges on one surface read as a SET: keep one treatment family per table/list - " \
          "the soft trio (+ outline for neutral) together, or the solid pair together; never a " \
          "solid destructive pill inside a soft status column (design lint flags the mix)."
        ].freeze

        style :variant, default: :default, required: true, variants: VARIANTS,
                        doc: "The intent axis; success/warning/info are the soft record-status treatments."

        option :href, :string,
               doc: "Renders the pill as a real <a> - a navigational chip; the theme's link hover treatments " \
                    "activate on exactly this element."

        part "badge", "The status pill itself (a <span>; a real <a> when href: is given) - " \
                      "the whole component is this one element",
             states: {
               "data-variant" => { condition: "always - the resolved variant",
                                   values: VARIANTS.map(&:to_s) }
             }

        # Enforces the visible-text content block.
        # @api private
        def before_render
          ensure_content!
        end

        # @api private
        def call
          content_tag(href.present? ? :a : :span, content, **root_attributes.to_attributes)
        end

        # @api private
        def root_attributes
          attrs = { "data-slot" => "badge", "data-variant" => variant }
          attrs["href"] = href if href.present?
          html_attributes.merge_if_not_set(attrs.merge(component_data_attributes))
        end

        private :root_attributes
      end
    end
  end
end
