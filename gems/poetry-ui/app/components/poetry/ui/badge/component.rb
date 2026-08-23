# frozen_string_literal: true

module Poetry
  module Ui
    module Badge
      # The Badge - shadcn new-york-v4 parity: four upstream variants on
      # semantic tokens, dark destructive at /60 (the composited treatment
      # the contrast gate models) - PLUS the poetry-original soft status
      # trio (success/warning/info on the status tokens, the muted
      # color-coded pills record-status columns need). Template-less.
      #
      # @example A soft status pill
      #   render Poetry::Ui::Badge::Component.new(variant: :success) { "Fulfilled" }
      class Component < Poetry::Core::Component
        # A status label with no text is an invisible sliver (a stray
        # label: attribute once rendered an empty pill).
        requires_content "the visible status text"

        VARIANTS = %i[default secondary destructive outline ghost link success warning info].freeze

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

        style :variant, default: :default, required: true, variants: VARIANTS

        # Badge-as-link (upstream badge#link parity): href: renders the pill
        # as a real <a> - the theme layer already ships the [a&]:hover
        # treatments for exactly this element.
        option :href, :string

        part "badge", "The status pill itself (a <span>; a real <a> when href: is given) - " \
                      "the whole component is this one element",
             states: {
               "data-variant" => { condition: "always - the resolved variant",
                                   values: VARIANTS.map(&:to_s) }
             }

        def before_render
          ensure_content!
        end

        def call
          content_tag(href.present? ? :a : :span, content, **root_attributes.to_attributes)
        end

        def root_attributes
          attrs = { "data-slot" => "badge", "data-variant" => variant }
          attrs["href"] = href if href.present?
          html_attributes.merge_if_not_set(attrs.merge(component_data_attributes))
        end
      end
    end
  end
end
