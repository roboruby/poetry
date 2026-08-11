# frozen_string_literal: true

module Poetry
  module Ui
    module Card
      # The Card - shadcn new-york-v4 parity via data-slot composition
      # One component whose parts are slots arranged by the template;
      # every part carries its data-slot role, and the header grid reacts
      # to the presence of an action via has-data-[slot=card-action].
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "Compose with the slots (title/description/action/footer) - never rebuild the header grid by hand.",
          "The card body is the content block; use CardAction for the header-corner control.",
          "The title renders as a real heading (h3 default) - set title_tag: to fit the page outline."
        ].freeze

        # A real HEADING (h3 by default) - a deliberate a11y improvement
        # over shadcn's div, caught by the eval harness's heading_semantics
        # gate (2026-07-01). Visual classes unchanged, so parity holds.
        option :title_tag, :symbol, default: :h3

        # The body cell's class merge seam (caller classes win via
        # tailwind_merge, the footer's existing pattern) - the chat-in-a-
        # card posture needs the content cell to flex and drop its padding
        # (min-h-0 flex-1 p-0), exactly what upstream passes to
        # CardContent.
        option :content_class, :string

        validates :title_tag, inclusion: { in: %i[h1 h2 h3 h4 h5 h6] }

        part "card", "Root container - the vertical flex stack"
        part "card-header", "The title row grid - gains a trailing auto column when " \
                            "card-action is present"
        part "card-title", "The heading (title_tag, h3 by default)"
        part "card-description", "Muted one-liner under the title"
        part "card-action", "The header's trailing corner control"
        part "card-content", "The body - the content block renders here"
        part "card-footer", "The bottom row (actions/meta)"

        renders_one :title
        renders_one :description
        renders_one :action
        # class: merges into the footer div (upstream CardFooter className -
        # the border-t divider variant is the canonical use).
        renders_one :footer, lambda { |**options, &block|
          @footer_class = options[:class]
          @footer_block = block
          nil
        }

        attr_reader :footer_class, :footer_block

        def header?
          title? || description? || action?
        end

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "card" }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
