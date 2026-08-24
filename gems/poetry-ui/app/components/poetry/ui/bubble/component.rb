# frozen_string_literal: true

module Poetry
  module Ui
    module Bubble
      # The message surface of the AI-chat set: one bubble per message, 7
      # variants on semantic tokens, content polymorphic via tag: (:button /
      # :a quick replies), an optional reactions pill overlay. Purely
      # presentational - no controller.
      #
      # @example An assistant reply
      #   render Poetry::Ui::Bubble::Component.new(variant: :secondary) { "Here's the summary." }
      class Component < Poetry::Core::Component
        VARIANTS = %i[default secondary muted tinted outline ghost destructive].freeze
        ALIGNS = %i[start end].freeze
        CONTENT_TAGS = %i[div button a].freeze

        AGENT_RULES = [
          "One Bubble per message; stack a sender's run inside poetry_bubble_group.",
          "Quick replies are tag: :button (with the caller's data-action) or tag: :a + " \
          "href: - never a click handler on a div.",
          "ghost is for tool output / system text flowing full-width - not a visual preference.",
          "Reactions REQUIRE label: (the accessible name for the cluster).",
          "Inside a Message, alignment follows the Message's align - do not set both."
        ].freeze

        renders_one :reactions, lambda { |label:, side: :bottom, align: :end, &block|
          content_tag(:div,
                      class: css(:reactions), "data-slot" => "bubble-reactions",
                      "data-side" => side, "data-align" => align,
                      role: "group", "aria-label" => label, &block)
        }

        style :variant, default: :default, required: true, variants: VARIANTS

        option :align, :symbol, default: :start
        option :tag, :symbol, default: :div
        option :href, :string

        validates :align, inclusion: { in: ALIGNS }
        validates :tag, inclusion: { in: CONTENT_TAGS }

        part "bubble", "The message surface root - variant and alignment ride here",
             states: {
               "data-variant" => { condition: "always - the resolved variant",
                                   values: VARIANTS.map(&:to_s) },
               "data-align" => { condition: "always - the resolved align",
                                 values: ALIGNS.map(&:to_s) }
             }
        part "bubble-content", "The body (<div>, or a <button>/<a> quick reply via tag:) - " \
                               "the content block renders here"
        part "bubble-reactions", "The reactions pill overlay (role=group, named by label:)",
             states: {
               "data-side" => "always - which edge the pill overlays (default bottom)",
               "data-align" => "always - placement along that edge (default end)"
             }

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "bubble", "data-variant" => variant, "data-align" => align }
              .merge(component_data_attributes)
          )
        end

        # href: implies the anchor (the Button doctrine) - an href on the
        # default :div would otherwise be silently dropped, the dead-control
        # bug class the suite memorializes on Button.
        def content_tag_name
          href.present? ? :a : tag
        end

        def content_attributes
          attrs = { class: css(:content), "data-slot" => "bubble-content" }
          attrs[:href] = href if content_tag_name == :a
          attrs[:type] = "button" if content_tag_name == :button
          attrs
        end
      end
    end
  end
end
