# frozen_string_literal: true

module Poetry
  module Motion
    module TiltCard
      # A surface that leans toward a fine pointer and springs back flat
      # when it leaves. It wraps whatever it is given, a poetry Card most
      # often. The lean rotates an inner layer, never the outer element,
      # and the server renders the card flat; touch, coarse pointers and
      # reduced motion leave it that way.
      #
      # @example
      #   <%= poetry_tilt_card do %>
      #     <%= poetry_card do |card| %>...<% end %>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Motion::Options

        requires_content "the surface that tilts, a card most often"

        AGENT_RULES = [
          "Never put a popover, menu, select, combobox, tooltip or hover card trigger inside a tilt card: " \
          "the tilted layer becomes the containing block for their fixed-position panels. poetry check " \
          "flags it.",
          "The lean is decoration: nothing on the card may depend on it, and the card reads the same flat."
        ].freeze

        use_behavior :pointer
        use_behavior :spring

        use_stimulus do
          on :root do
            controller :tilt_card do
              register
              value :max
              value :spring
              value :animate, false, unless: :animate
            end
          end
          on :layer do
            controller(:tilt_card) { target :layer }
          end
        end

        motion_options spring: :snappy
        option :max, :integer, default: 8, doc: "The largest lean, in degrees."

        part "tilt-card", "The perspective wrapper; never transformed itself"
        part "tilt-card-layer", "The layer that leans",
             vars: { "--tilt-x" => "the lean around the vertical axis, in degrees",
                     "--tilt-y" => "the lean around the horizontal axis, in degrees" }

        def before_render
          ensure_content!
          ensure_within!(:max, 1..30)
        end

        def call
          tag.div(**root_attributes) do
            tag.div(content, "data-slot" => "tilt-card-layer", class: css(:layer), **stimulus_attributes_for(:layer))
          end
        end
      end
    end
  end
end
