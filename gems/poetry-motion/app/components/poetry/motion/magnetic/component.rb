# frozen_string_literal: true

module Poetry
  module Motion
    module Magnetic
      # A wrapper that pulls its content a few pixels toward a fine pointer
      # and springs it home when the pointer leaves - a magnetic button. Only
      # an inner layer moves; the wrapped control keeps its hit area, its
      # focus ring and its place in the layout.
      #
      # @example
      #   <%= poetry_magnetic do %>
      #     <%= poetry_button { "Get started" } %>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Motion::Options

        requires_content "the control the pointer pulls"

        AGENT_RULES = [
          "Wrap one control, a call to action; a page of magnetic controls is noise. The pull is " \
          "decoration and never the only cue that something is interactive."
        ].freeze

        use_behavior :pointer
        use_behavior :spring

        use_stimulus do
          on :root do
            controller :magnetic, if: :animate do
              register
              value :strength
              value :spring
            end
          end
          on :layer do
            controller(:magnetic, if: :animate) { target :layer }
          end
        end

        motion_options spring: :snappy
        option :strength, :integer, default: 8, doc: "The farthest the content moves, in pixels."

        part "magnetic", "The wrapper that catches the pointer; never moves itself"
        part "magnetic-layer", "The layer that moves",
             vars: { "--magnet-x" => "the pull along x, in pixels", "--magnet-y" => "the pull along y, in pixels" }

        def before_render
          ensure_content!
          ensure_within!(:strength, 1..40)
        end

        def call
          tag.span(**root_attributes) do
            tag.span(content, "data-slot" => "magnetic-layer", class: css(:layer), **stimulus_attributes_for(:layer))
          end
        end
      end
    end
  end
end
