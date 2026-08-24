# frozen_string_literal: true

module Poetry
  module Ui
    # A transcript divider or inline status line for chat UIs.
    module Marker
      # A transcript divider or inline status line for chat UIs: date
      # breaks, "3 new messages", an in-flight status. The label is real
      # announced content - the decorative divider lines render around
      # it, and the marker never takes a separator role. announce:
      # :status turns it into a live status region for the single
      # in-flight marker a transcript shows while streaming.
      #
      # @example
      #   render Poetry::Ui::Marker::Component.new(variant: :separator) { "Yesterday" }
      class Component < Poetry::Core::Component
        # The closed vocabulary for the variant axis.
        VARIANTS = %i[default separator border].freeze
        # The closed vocabulary for the announce axis.
        ANNOUNCE = %i[none status].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "The marker text is real announced content - never mark it aria-hidden or role=separator.",
          "announce: :status is for the ONE in-flight marker (streaming status); static dividers never announce.",
          "Icons ride the icon slot (decorative always): with_icon(name:) for a lucide glyph, " \
          "with_icon { } for other media (a Spinner mid-run).",
          "Use variant: :separator for date/section breaks; :border under pinned headers."
        ].freeze

        slot_doc :icon, "Optional leading visual: name: renders an icon glyph; a block carries other media (a " \
                        "Spinner mid-run). Either way it sits in an aria-hidden cell and stays decorative - the " \
                        "marker root does the announcing."
        renders_one :icon, lambda { |name: nil, **options, &block|
          next Poetry::Ui::Icon::Component.new(name: name, **options) if name

          content_tag(:span, &block)
        }

        style :variant, default: :default, required: true, variants: VARIANTS,
                        doc: "The divider treatment - :separator for date/section breaks, :border for a full-width " \
                             "rule under pinned headers."

        option :tag, :symbol, default: :div, doc: "The root element's tag."
        option :announce, :symbol, default: :none,
                                   doc: "Makes the marker a live status region (role=status) for the one in-flight " \
                                        "marker; static dividers never announce."

        validates :announce, inclusion: { in: ANNOUNCE }

        part "marker", "The divider/status root - the label is real announced content " \
                       "(role=status when announce: :status; never role=separator)",
             states: {
               "data-variant" => { condition: "always - the resolved variant",
                                   values: VARIANTS.map(&:to_s) }
             }
        # "The label IS the information" - an empty marker renders a bare
        # divider span pretending to inform.
        requires_content "the marker label"

        part "marker-icon", "Decorative icon wrapper (aria-hidden always)"
        part "marker-content", "The label span - the marker text itself"

        # @api private
        def before_render
          ensure_content!
        end

        # @api private
        def root_attributes
          attrs = { "data-slot" => "marker", "data-variant" => variant }.merge(component_data_attributes)
          attrs["role"] = "status" if announce == :status
          html_attributes.merge_if_not_set(attrs)
        end

        private :root_attributes
      end
    end
  end
end
