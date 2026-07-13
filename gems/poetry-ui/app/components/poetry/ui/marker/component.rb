# frozen_string_literal: true

module Poetry
  module Ui
    module Marker
      # Transcript dividers / inline status for the AI-chat set
      # (Marker): date breaks, "3 new messages",
      # in-flight status lines. The label IS the information - announced
      # content by default, NEVER role="separator" (the divider lines are
      # pseudo-elements AT cannot see). announce: :status formalizes the
      # live in-flight marker (one per transcript - the anti-spam rule).
      class Component < Poetry::Core::Component
        VARIANTS = %i[default separator border].freeze
        ANNOUNCE = %i[none status].freeze

        AGENT_RULES = [
          "The marker text is real announced content - never mark it aria-hidden or role=separator.",
          "announce: :status is for the ONE in-flight marker (streaming status); static dividers never announce.",
          "Icons in markers ride the typed icon slot (decorative always).",
          "Use variant: :separator for date/section breaks; :border under pinned headers."
        ].freeze

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
        part "marker-icon", "Decorative icon wrapper (aria-hidden always)"
        part "marker-content", "The label span - the marker text itself"

        renders_one :icon, Poetry::Ui::Icon::Component

        def root_attributes
          attrs = { "data-slot" => "marker", "data-variant" => variant }.merge(component_data_attributes)
          attrs["role"] = "status" if announce == :status
          html_attributes.merge_if_not_set(attrs)
        end
      end
    end
  end
end
