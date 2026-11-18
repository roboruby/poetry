# frozen_string_literal: true

module Poetry
  module Motion
    module Confetti
      # A burst of confetti over the page: from a click on the control it
      # wraps (trigger: :click), or once when it renders (trigger: :load, for
      # a success message a Turbo Stream delivers). The full-viewport canvas
      # is server-rendered, aria-hidden and never takes a pointer; the
      # canvas-confetti kernel loads on the first burst. Reduced motion
      # bursts nothing.
      #
      # @example
      #   <%= poetry_confetti do %>
      #     <%= poetry_button { "Ship it" } %>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Motion::Options

        AGENT_RULES = [
          "Confetti celebrates a moment the user caused - a finished task, a purchase. It never carries " \
          "the message: say what happened in text, and let the confetti decorate it."
        ].freeze

        use_behavior :canvas

        use_stimulus do
          on :root do
            controller :confetti, if: :animate do
              register
              value :trigger
              value :count
              value :spread
            end
          end
          on :canvas do
            controller(:confetti, if: :animate) { target :canvas }
          end
        end

        motion_options trigger: :click, triggers: %i[click load]
        option :count, :integer, default: 120, doc: "How many pieces per burst."
        option :spread, :integer, default: 70, doc: "The burst's spread, in degrees."

        part "confetti", "The control the burst comes from, or the moment it marks"
        part "confetti-canvas", "The full-viewport, aria-hidden canvas the pieces fly on"

        def before_render
          ensure_within!(:count, 1..500)
          ensure_within!(:spread, 1..360)
        end

        def call
          tag.span(**root_attributes) do
            canvas = tag.canvas("aria-hidden" => "true", "data-slot" => "confetti-canvas", class: css(:canvas),
                                **stimulus_attributes_for(:canvas))
            safe_join([content, canvas].compact)
          end
        end
      end
    end
  end
end
