# frozen_string_literal: true

module Poetry
  module Motion
    module AnimatedList
      # A list whose Turbo Stream changes animate: appended items fade in,
      # removed items fade out, and the rest slide to their new places. The
      # server renders the list as it is, and a stream's own render does
      # the change; the effect only animates it, as a layout transition.
      #
      # @example A feed that streams new entries in
      #   <%= poetry_animated_list(id: "comments") do %>
      #     <%= render @comments %>
      #   <% end %>
      #   <%# a turbo_stream.append "comments" from the server now animates %>
      class Component < Poetry::Core::Component
        include Poetry::Motion::Options

        requires_content "the list's items"

        # The elements the list can render as.
        TAGS = %i[ul ol div].freeze

        AGENT_RULES = [
          "Give the list an id: and target it (or its items) with Turbo Streams; the streams animate, " \
          "the server-rendered list is the finished state.",
          "Each direct child is one item. Keep item elements stable across renders so survivors slide " \
          "instead of fading out and back in."
        ].freeze

        use_behavior :layout

        use_stimulus do
          on :root do
            controller :animated_list, if: :animate do
              register
              value :duration, from: :duration_ms
            end
          end
        end

        motion_options duration: :normal
        option :as, :symbol, default: :ul, doc: "The element the list renders as: ul, ol or div."

        validates :as, inclusion: { in: TAGS }

        part "animated-list", "The list; its direct children are the items that enter, leave and move",
             states: { "data-animated-list" => "always - the list's own key, which names its items in the transition" }

        def before_render
          ensure_content!
          ensure_motion_options!
        end

        def call
          content_tag(as, content, **root_attributes)
        end

        def root_attributes
          super("data-animated-list" => poetry_instance_id("poetry-animated-list"))
        end

        private

        # The duration token as milliseconds for the controller.
        def duration_ms
          { "fast" => 150, "normal" => 300, "slow" => 600 }.fetch(duration.to_s) { duration.to_s.to_i }
        end
      end
    end
  end
end
