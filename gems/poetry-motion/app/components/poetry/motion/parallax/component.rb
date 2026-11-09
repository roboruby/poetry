# frozen_string_literal: true

module Poetry
  module Motion
    module Parallax
      # Content that drifts at its own pace as it scrolls through the
      # viewport - a hero image, a layered illustration. It rests where the
      # server put it when centered, and reduced motion leaves it there.
      #
      # @example
      #   <%= poetry_parallax(distance: 120) do %>
      #     <%= image_tag "hero.jpg", alt: "" %>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Motion::Options

        requires_content "the content that drifts"

        AGENT_RULES = [
          "Parallax is for decoration and imagery, never for text a reader is reading; keep the " \
          "distance small, and leave room so the drift never clips the content."
        ].freeze

        use_behavior :scroll_value

        use_stimulus do
          on :root do
            controller :parallax, if: :animate do
              register
              value :distance
            end
          end
        end

        motion_options
        option :distance, :integer, default: 80,
                                    doc: "Pixels of drift from entering the viewport to leaving it; negative " \
                                         "drifts the other way."

        part "parallax", "The drifting content",
             vars: { "--parallax-y" => "the current drift, in pixels; 0 when centered" }

        def before_render
          ensure_content!
          ensure_within!(:distance, -400..400)
        end

        def call
          tag.div(content, **root_attributes)
        end
      end
    end
  end
end
