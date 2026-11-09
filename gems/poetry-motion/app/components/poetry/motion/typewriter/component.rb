# frozen_string_literal: true

module Poetry
  module Motion
    module Typewriter
      # A line typed out a character at a time when it comes into view. The
      # server renders the whole line; a screen reader reads it once, and
      # the typing runs in an aria-hidden copy that ends on the line itself.
      #
      # @example
      #   <%= poetry_typewriter("Ship the finished page first.", class: "text-2xl") %>
      class Component < Poetry::Core::Component
        include Poetry::Motion::Options

        AGENT_RULES = [
          "Type one short line, a headline or a prompt; never body copy or anything a reader must " \
          "wait for. The line is complete in the page before it types."
        ].freeze

        use_stimulus do
          on :root do
            controller :typewriter, if: :animate do
              register
              value :speed
              value :delay, if: -> { delay.positive? }
              value :trigger
            end
          end
          on :display do
            controller(:typewriter, if: :animate) { target :display }
          end
        end

        motion_options trigger: :in_view, delay: 0, triggers: %i[load in_view]
        option :text, :string, required: true, doc: "The line, plain text."
        option :speed, :integer, default: 50, doc: "Milliseconds per character."
        option :cursor, :boolean, default: true, doc: "Shows a caret after the text while it types."

        part "typewriter", "The line; a caret follows the text while it types",
             states: { "data-typing" => "the line is typing", "data-cursor" => "the caret is on (cursor:)" }
        part "typewriter-display", "The aria-hidden copy that types"

        def initialize(text = nil, **options)
          super(**(text.nil? ? options : options.merge(text: text)))
        end

        def before_render
          ensure_motion_options!
          ensure_within!(:speed, 5..1000)
        end

        def call
          tag.span(**root_attributes) do
            safe_join([content_tag(:span, text, class: css(:reader)),
                       content_tag(:span, text, "aria-hidden" => "true", "data-slot" => "typewriter-display",
                                                **stimulus_attributes_for(:display))])
          end
        end

        def root_attributes
          super(cursor ? { "data-cursor" => "" } : {})
        end
      end
    end
  end
end
