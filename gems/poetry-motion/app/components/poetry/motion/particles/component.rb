# frozen_string_literal: true

module Poetry
  module Motion
    module Particles
      # A field of slow-drifting dots behind its content, optionally linked by
      # faint lines - drawn on a server-rendered, aria-hidden canvas. It is
      # the canvas pattern: drawn every visible frame, paused off screen and
      # in hidden tabs, one still frame under reduced motion. The dots take
      # the canvas's text color; set it with a text-* class.
      #
      # @example A hero over linked particles
      #   <%= poetry_particles(link: 90, class: "py-24 text-primary/40") do %>
      #     <h1>...</h1>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Motion::Options

        AGENT_RULES = [
          "Particles are a background: the content stands on its own and keeps its contrast without them."
        ].freeze

        use_behavior :canvas
        use_behavior :frame

        use_stimulus do
          on :root do
            controller :particles, if: :animate do
              register
              value :count
              value :speed
              value :link, if: -> { link.positive? }
            end
          end
          on :canvas do
            controller(:particles, if: :animate) { target :canvas }
          end
        end

        motion_options
        option :count, :integer, default: 60, doc: "How many dots."
        option :speed, :integer, default: 12, doc: "Drift speed, in pixels per second."
        option :link, :integer, default: 0, doc: "Pixels within which two dots are linked by a line; 0 links none."

        part "particles", "The region; the canvas sits behind its content"
        part "particles-canvas", "The aria-hidden canvas the dots are drawn on"

        def before_render
          ensure_within!(:count, 1..300)
          ensure_within!(:speed, 0..200)
          ensure_within!(:link, 0..300)
        end

        def call
          tag.div(**root_attributes) do
            canvas = tag.canvas("aria-hidden" => "true", "data-slot" => "particles-canvas", class: css(:canvas),
                                **stimulus_attributes_for(:canvas))
            safe_join([canvas, (tag.div(content, class: css(:content)) if content.present?)].compact)
          end
        end
      end
    end
  end
end
