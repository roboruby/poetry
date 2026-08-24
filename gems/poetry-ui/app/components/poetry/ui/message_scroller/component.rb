# frozen_string_literal: true

module Poetry
  module Ui
    # A streaming-aware chat transcript scroller.
    module MessageScroller
      # A scrollable chat transcript that follows the newest message
      # while streaming, releases when the reader scrolls up, and offers
      # a jump-to-latest button. Without JavaScript it is a plain
      # scrollable region, fully readable.
      #
      # The content element is the Turbo Stream append target (stable
      # dom id "<id>-messages"); rows are poetry_message_scroller_item
      # wrappers keyed by message id. History prepends keep the reading
      # position; a row rendered with anchor: true becomes the held
      # reading line.
      #
      # @example A chat transcript
      #   render Poetry::Ui::MessageScroller::Component.new(id: "chat") do
      #     # poetry_message_scroller_item rows
      #   end
      class Component < Poetry::Core::Component
        # The closed vocabulary for the default_scroll_position axis.
        SCROLL_POSITIONS = %i[start end last-anchor].freeze

        # Projected into the registry, llms.txt, and the agent surface.
        AGENT_RULES = [
          "Stream by UPDATING a row's text (morph/replace) - appending nodes per token re-announces the row to AT.",
          "Rows are poetry_message_scroller_item(id: message.id) - the id is how anchoring and Streams find them.",
          "Append new turns with a Turbo Stream targeting the content element's dom id.",
          "History loads PREPEND into the content element - the controller preserves the reading position.",
          "Never nest a second scroll container inside the viewport."
        ].freeze

        use_stimulus do
          on :root do
            controller :message_scroller do
              register
              value :auto_scroll
              value :default_scroll_position
              value :preserve_scroll_on_prepend
              value :track_visibility
            end
          end
          on :viewport do
            controller(:message_scroller) { target :viewport }
          end
          on :content do
            controller(:message_scroller) { target :content }
          end
          on :spacer do
            controller(:message_scroller) { target :spacer }
          end
          # The jump affordance: a bare descriptor (element-default click)
          # plus the button target, forwarded into Button kwargs.
          on :jump_button do
            controller :message_scroller do
              target :button
              action :scroll_to_end
            end
          end
        end

        option :id, :string, required: true,
                             doc: "The transcript's stable identifier - the content element renders dom id " \
                                  "\"<id>-messages\" for Turbo Streams to target."
        option :auto_scroll, :boolean, default: true,
                                       doc: "Follows the newest message while the reader sits at the bottom; " \
                                            "scrolling up releases the follow."
        option :default_scroll_position, :symbol, default: :end,
                                                  doc: "Where the viewport lands on connect: the newest message " \
                                                       "(:end), the oldest (:start), or the last anchor: true row " \
                                                       "(:\"last-anchor\")."
        option :preserve_scroll_on_prepend, :boolean, default: true,
                                                      doc: "Keeps the reading position stable when history prepends " \
                                                           "into the content element."
        option :track_visibility, :boolean, default: false,
                                            doc: "Opt-in observation of which rows are on screen - emits a " \
                                                 "visibility event as the visible set changes."
        option :jump_button, :boolean, default: true,
                                       doc: "Renders the floating jump-to-latest button (shown once the reader " \
                                            "leaves the bottom)."

        validates :default_scroll_position, inclusion: { in: SCROLL_POSITIONS }

        part "message-scroller", "The transcript root the controller drives - runtime " \
                                 "scroll state is mirrored here",
             states: {
               "data-mode" => { condition: "always once connected - the 4-state machine",
                                values: %w[following-bottom free-scrolling
                                           anchored-to-message settling-jump] },
               "data-scrollable" => "overflow exists - carries which edges have room " \
                                    "(start, end, or both as a space-separated pair)",
               "data-autoscrolling" => "a programmatic scroll is settling - the " \
                                       "follow-bottom release is suppressed while set"
             }
        part "message-scroller-viewport", "The native scroll region (role=region, " \
                                          "focusable) - the controller mirrors the same " \
                                          "runtime attributes here",
             states: {
               "data-scrollable" => "overflow exists - the same edge tokens as the root",
               "data-autoscrolling" => "a programmatic scroll is settling"
             }
        part "message-scroller-content", "The row container and Turbo Stream append target " \
                                         "(stable dom id <id>-messages); role=log announces " \
                                         "additions"
        part "message-scroller-item", "One transcript row (poetry_message_scroller_item) - " \
                                      "the id is how anchoring and Streams find it",
             states: {
               "data-message-id" => "always - the row's message id",
               "data-scroll-anchor" => "anchor: true - the turn the controller holds at " \
                                       "the reading line"
             }
        part "message-scroller-spacer", "Tail spacer faking scroll room below a short " \
                                        "anchored turn - hidden at height 0"

        # @api private
        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "message-scroller" }
              .merge(stimulus_attributes_for(:root))
              .merge(component_data_attributes)
          )
        end

        # @api private
        def viewport_attributes
          {
            "class" => css(:viewport), "data-slot" => "message-scroller-viewport",
            "role" => "region", "tabindex" => "0",
            "aria-label" => t("poetry.message_scroller.region")
          }.merge(stimulus_attributes_for(:viewport))
        end

        # @api private
        def content_attributes
          {
            "id" => "#{id}-messages", "class" => css(:content),
            "data-slot" => "message-scroller-content",
            "role" => "log", "aria-relevant" => "additions"
          }.merge(stimulus_attributes_for(:content))
        end

        # @api private
        def spacer_attributes
          { "data-slot" => "message-scroller-spacer", "aria-hidden" => "true", "hidden" => true }
            .merge(stimulus_attributes_for(:spacer))
        end

        # @api private
        def button_attributes
          {
            class: css(:button),
            data: { slot: "message-scroller-button", direction: "end", active: "false" },
            tabindex: "-1"
          }.merge(stimulus_attributes_for(:jump_button))
        end

        private :root_attributes, :viewport_attributes, :content_attributes, :spacer_attributes, :button_attributes
      end
    end
  end
end
