# frozen_string_literal: true

module Poetry
  module Ui
    module Badge
      # The Badge - shadcn new-york-v4 parity: four upstream variants on
      # semantic tokens, dark destructive at /60 (the composited treatment
      # the contrast gate models) - PLUS the poetry-original soft status
      # trio (Blocks v1.1: success/warning/info on the status
      # tokens, the muted color-coded pills the judged benchmark measured
      # as missing). Template-less.
      class Component < Poetry::Core::Component
        VARIANTS = %i[default secondary destructive outline success warning info].freeze

        AGENT_RULES = [
          "Badges are non-interactive status labels - never attach click handlers; use Button for actions.",
          "The visible text is the content block: render ... { \"beta\" } - there is no label: option.",
          "Pick the variant by intent (destructive = error states; success/warning/info = record " \
          "status, e.g. Fulfilled/Processing/Syncing), never by color preference.",
          "Status badges on one surface read as a SET: keep one treatment family per table/list - " \
          "the soft trio (+ outline for neutral) together, or the solid pair together; never a " \
          "solid destructive pill inside a soft status column (design lint flags the mix)."
        ].freeze

        style :variant, default: :default, required: true, variants: VARIANTS

        # A status label with no text is an invisible sliver (browser pass,
        # 2026-07-01 - a stray label: attribute rendered an empty pill).
        requires_content "the visible status text"

        def before_render
          ensure_content!
        end

        def call
          content_tag(:span, content, **root_attributes.to_attributes)
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "badge", "data-variant" => variant }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
