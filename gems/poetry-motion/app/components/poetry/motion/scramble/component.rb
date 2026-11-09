# frozen_string_literal: true

module Poetry
  module Motion
    module Scramble
      # Text that decodes from random glyphs into itself, left to right,
      # when it comes into view. The server renders the text; a screen
      # reader reads it once, and the scramble runs in an aria-hidden copy
      # that lands on the text itself.
      #
      # @example
      #   <%= poetry_scramble("ACCESS GRANTED", class: "font-mono") %>
      class Component < Poetry::Core::Component
        include Poetry::Motion::Options

        AGENT_RULES = [
          "Scramble a short label or heading, ideally in a monospace face so the width holds; never " \
          "text a reader needs mid-animation."
        ].freeze

        use_stimulus do
          on :root do
            controller :scramble, if: :animate do
              register
              value :duration, from: :duration_ms
              value :delay, if: -> { delay.positive? }
              value :trigger
            end
          end
          on :display do
            controller(:scramble, if: :animate) { target :display }
          end
        end

        motion_options duration: :slow, trigger: :in_view, delay: 0, triggers: %i[load in_view]
        option :text, :string, required: true, doc: "The text, plain."

        part "scramble", "The text"
        part "scramble-display", "The aria-hidden copy that scrambles"

        def initialize(text = nil, **options)
          super(**(text.nil? ? options : options.merge(text: text)))
        end

        def before_render
          ensure_motion_options!
        end

        def call
          tag.span(**root_attributes) do
            safe_join([content_tag(:span, text, class: css(:reader)),
                       content_tag(:span, text, "aria-hidden" => "true", "data-slot" => "scramble-display",
                                                **stimulus_attributes_for(:display))])
          end
        end

        private

        # The duration as milliseconds for the controller; the slow token is longer here, a decode.
        def duration_ms
          { "fast" => 400, "normal" => 800, "slow" => 1200 }.fetch(duration.to_s) { duration.to_s.to_i }
        end
      end
    end
  end
end
