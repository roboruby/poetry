# frozen_string_literal: true

module Poetry
  module Ui
    # One chat turn's row in a conversation transcript.
    module Message
      # One chat turn's row: an avatar beside a content column of
      # header, message bubbles (the body block), and footer. align:
      # :end mirrors the row for the local user's side. Purely
      # presentational - no JavaScript.
      #
      # @example
      #   render Poetry::Ui::Message::Component.new do |message|
      #     message.with_avatar { "AI" }
      #     message.with_header { "Assistant" }
      #     tag.div("Here's the plan for today.")
      #   end
      class Component < Poetry::Core::Component
        # The closed vocabulary for the align axis.
        ALIGNS = %i[start end].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "One Message per turn: avatar slot + header/footer slots; the body block holds the Bubbles.",
          "align: :end is the local user's side - set it on the Message, never on the Bubbles inside.",
          "The avatar slot is decorative context by default - pass meaningful sender identity in the header.",
          "Timestamps and delivery state belong in the footer slot (it lifts the avatar automatically)."
        ].freeze

        # The sender's avatar, kept beside the content column - decorative
        # context; put meaningful sender identity in the header.
        renders_one :avatar
        # The sender identity line above the bubbles.
        renders_one :header
        # Timestamps / delivery state below the bubbles.
        renders_one :footer

        # Which side the row sits on; :end mirrors it for the local user's side.
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

        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "message", "data-align" => align }.merge(component_data_attributes)
          )
        end
      end
    end
  end
end
