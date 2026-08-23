# frozen_string_literal: true

module Poetry
  module Ui
    module MessageScroller
      # The streaming-aware transcript -
      # the Gen-UI centerpiece: a native scroll region driven by the
      # poetry--core--message-scroller 4-state machine. Baseline without
      # JS: a plain scrollable region, fully readable. The content element
      # is the Turbo Stream append target (stable dom id); rows are
      # poetry_message_scroller_item wrappers.
      #
      # The controller's autoScroll default is the source-faithful FALSE;
      # this wrapper is poetry's opinionated chat posture and renders the
      # value TRUE unless auto_scroll: false.
      #
      # @example A chat transcript
      #   render Poetry::Ui::MessageScroller::Component.new(id: "chat") do
      #     # poetry_message_scroller_item rows
      #   end
      class Component < Poetry::Core::Component
        SCROLL_POSITIONS = %i[start end last-anchor].freeze

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

        option :id, :string, required: true
        option :auto_scroll, :boolean, default: true
        option :default_scroll_position, :symbol, default: :end
        option :preserve_scroll_on_prepend, :boolean, default: true
        option :track_visibility, :boolean, default: false
        option :jump_button, :boolean, default: true

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

        def root_attributes
          html_attributes.merge_if_not_set(
            { "data-slot" => "message-scroller" }
              .merge(stimulus_attributes_for(:root))
              .merge(component_data_attributes)
          )
        end

        def viewport_attributes
          {
            "class" => css(:viewport), "data-slot" => "message-scroller-viewport",
            "role" => "region", "tabindex" => "0",
            "aria-label" => t("poetry.message_scroller.region")
          }.merge(stimulus_attributes_for(:viewport))
        end

        def content_attributes
          {
            "id" => "#{id}-messages", "class" => css(:content),
            "data-slot" => "message-scroller-content",
            "role" => "log", "aria-relevant" => "additions"
          }.merge(stimulus_attributes_for(:content))
        end

        def spacer_attributes
          { "data-slot" => "message-scroller-spacer", "aria-hidden" => "true", "hidden" => true }
            .merge(stimulus_attributes_for(:spacer))
        end

        def button_attributes
          {
            class: css(:button),
            data: { slot: "message-scroller-button", direction: "end", active: "false" },
            tabindex: "-1"
          }.merge(stimulus_attributes_for(:jump_button))
        end
      end
    end
  end
end
