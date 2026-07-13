# frozen_string_literal: true

module Poetry
  module Ui
    module Message
      # The chat-row layout of the AI-chat set (Message):
      # avatar + a content column (header / bubbles / footer), mirrored by
      # align: :end. Purely presentational - no controller; alignment and
      # the ghost-Bubble padding collapse are CSS context selectors.
      class Component < Poetry::Core::Component
        ALIGNS = %i[start end].freeze

        AGENT_RULES = [
          "One Message per turn: avatar slot + header/footer slots; the body block holds the Bubbles.",
          "align: :end is the local user's side - set it on the Message, never on the Bubbles inside.",
          "The avatar slot is decorative context by default - pass meaningful sender identity in the header.",
          "Timestamps and delivery state belong in the footer slot (it lifts the avatar automatically)."
        ].freeze

        option :align, :symbol, default: :start

        validates :align, inclusion: { in: ALIGNS }

        part "message", "The chat-row root - avatar plus a content column; align: :end " \
                        "mirrors the row for the local user's side",
             states: {
               "data-align" => { condition: "always - the resolved align",
                                 values: ALIGNS.map(&:to_s) }
             }
        part "message-avatar", "The avatar slot's box, kept out of the content column"
        part "message-content", "The content column - header, the body block (the Bubbles), " \
                                "footer"
        part "message-header", "Sender identity line above the bubbles (header slot)"
        part "message-footer", "Timestamps / delivery state below the bubbles (footer slot - " \
                               "it lifts the avatar)"

        renders_one :avatar
        renders_one :header
        renders_one :footer

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "message", "data-align" => align }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
