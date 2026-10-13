# frozen_string_literal: true

module Poetry
  module Motion
    module SpotlightCard
      # A surface with a soft glow that follows a fine pointer across it. It
      # wraps whatever it is given, a poetry Card most often. The glow is a
      # radial gradient behind the content, drawn from two custom
      # properties; no engine loads, and the server renders the surface
      # without it.
      #
      # @example
      #   <%= poetry_spotlight_card do %>
      #     <%= poetry_card do |card| %>...<% end %>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Motion::Options

        requires_content "the surface the glow follows the pointer across"

        AGENT_RULES = [
          "The glow is decoration: the surface reads the same without it, and it never carries state."
        ].freeze

        use_behavior :pointer

        use_stimulus do
          on :root do
            controller(:spotlight_card, if: :animate) { register }
          end
        end

        motion_options
        option :size, :integer, default: 320, doc: "The glow's diameter in pixels."

        part "spotlight-card", "The surface; ::before draws the glow",
             vars: { "--spotlight-x" => "the pointer's x within the card",
                     "--spotlight-y" => "the pointer's y within the card",
                     "--spotlight-opacity" => "1 while a fine pointer is over the card",
                     "--spotlight-size" => "the glow's diameter (size:)" }

        def before_render
          ensure_content!
          ensure_within!(:size, 40..2000)
        end

        def call
          tag.div(content, **root_attributes)
        end

        def root_attributes
          super("style" => "--spotlight-size: #{size}px")
        end
      end
    end
  end
end
