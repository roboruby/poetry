# frozen_string_literal: true

module Poetry
  module Ui
    module Marker
      # Transcript dividers / inline status for the AI-chat set: date
      # breaks, "3 new messages", in-flight status lines. The label IS
      # the information - announced content by default, NEVER
      # role="separator" (the divider lines are pseudo-elements AT cannot
      # see). announce: :status formalizes the live in-flight marker (one
      # per transcript - the anti-spam rule).
      #
      # @example
      #   render Poetry::Ui::Marker::Component.new(variant: :separator) { "Yesterday" }
      class Component < Poetry::Core::Component
        VARIANTS = %i[default separator border].freeze
        ANNOUNCE = %i[none status].freeze

        AGENT_RULES = [
          "The marker text is real announced content - never mark it aria-hidden or role=separator.",
          "announce: :status is for the ONE in-flight marker (streaming status); static dividers never announce.",
          "Icons ride the icon slot (decorative always): with_icon(name:) for a lucide glyph, " \
          "with_icon { } for other media (a Spinner mid-run).",
          "Use variant: :separator for date/section breaks; :border under pinned headers."
        ].freeze

        # name: renders the lucide icon; a block carries other media (a
        # Spinner mid-run - upstream's MarkerIcon is a generic wrapper).
        # Either way the template's aria-hidden icon cell keeps it
        # decorative: a block Spinner's own status role is hidden, and
        # the marker root does the announcing.
        renders_one :icon, lambda { |name: nil, **options, &block|
          next Poetry::Ui::Icon::Component.new(name: name, **options) if name

          content_tag(:span, &block)
        }

        style :variant, default: :default, required: true, variants: VARIANTS

        option :tag, :symbol, default: :div
        option :announce, :symbol, default: :none

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

        def before_render
          ensure_content!
        end

        def root_attributes
          attrs = { "data-slot" => "marker", "data-variant" => variant }.merge(component_data_attributes)
          attrs["role"] = "status" if announce == :status
          html_attributes.merge_if_not_set(attrs)
        end
      end
    end
  end
end
