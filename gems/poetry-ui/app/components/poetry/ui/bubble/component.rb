# frozen_string_literal: true

module Poetry
  module Ui
    # Chat message bubbles.
    module Bubble
      # A chat message bubble - one per message, aligned to the sender's
      # side. The content block is the message; tag: :button or :a (with
      # href:) turns the bubble into a quick reply, and the reactions slot
      # overlays a pill of reactions. Purely presentational - no
      # JavaScript.
      #
      # @example An assistant reply
      #   render Poetry::Ui::Bubble::Component.new(variant: :secondary) { "Here's the summary." }
      class Component < Poetry::Core::Component
        # The closed vocabulary for the variant axis.
        VARIANTS = %i[default secondary muted tinted outline ghost destructive].freeze
        # The closed vocabulary for the align axis.
        ALIGNS = %i[start end].freeze
        # The closed vocabulary for the tag: axis.
        CONTENT_TAGS = %i[div button a].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "One Bubble per message; stack a sender's run inside poetry_bubble_group.",
          "Quick replies are tag: :button (with the caller's data-action) or tag: :a + " \
          "href: - never a click handler on a div.",
          "ghost is for tool output / system text flowing full-width - not a visual preference.",
          "Reactions REQUIRE label: (the accessible name for the cluster).",
          "Inside a Message, alignment follows the Message's align - do not set both."
        ].freeze

        slot_doc :reactions, "The reactions pill overlaid on an edge; label: names the cluster for assistive tech, " \
                             "side:/align: place it (default bottom end)."
        renders_one :reactions, lambda { |label:, side: :bottom, align: :end, &block|
          content_tag(:div,
                      class: css(:reactions), "data-slot" => "bubble-reactions",
                      "data-side" => side, "data-align" => align,
                      role: "group", "aria-label" => label, &block)
        }

        # The content block IS the message; an empty bubble is an empty pill.
        requires_content "the message content"

        style :variant, default: :default, required: true, variants: VARIANTS,
                        doc: "The intent axis; :ghost is for tool output / system text flowing full-width."

        option :align, :symbol, default: :start,
                                doc: "Which side the bubble hugs; inside a Message, set the Message's align instead."
        option :tag, :symbol, default: :div,
                              doc: "The content element: :div (default), or :button/:a for a quick reply."
        option :href, :string, doc: "Renders the content as a real anchor; implies tag: :a."

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

        # Enforces the message content block.
        # @api private
        def before_render
          ensure_content!
        end

        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "bubble", "data-variant" => variant, "data-align" => align }
              .merge(component_data_attributes)
          )
        end

        # href: implies the anchor - an href on the default :div would
        # otherwise be silently dropped, leaving a dead control.
        # @api private
        def content_tag_name
          href.present? ? :a : tag
        end

        # @api private
        def content_attributes
          attrs = { class: css(:content), "data-slot" => "bubble-content" }
          attrs[:href] = href if content_tag_name == :a
          attrs[:type] = "button" if content_tag_name == :button
          attrs
        end

        private :root_attributes, :content_tag_name, :content_attributes
      end
    end
  end
end
