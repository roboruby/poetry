# frozen_string_literal: true

module Poetry
  module Motion
    module Dock
      # A row of items, links or buttons, that swell toward a fine pointer,
      # the nearest most - the magnifying launcher. Each direct child is
      # one item. The items keep their size in the layout and scale from
      # the edge the dock sits on, so nothing reflows; the server renders
      # them at rest, and touch and reduced motion leave them there.
      #
      # @example
      #   <%= poetry_dock(label: "Apps") do %>
      #     <% apps.each do |app| %><%= link_to app.icon, app, aria: { label: app.name } %><% end %>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Motion::Options

        requires_content "the items, each a direct child"

        # The ways a dock can run.
        ORIENTATIONS = %i[horizontal vertical].freeze

        AGENT_RULES = [
          "Each item is a real link or button with an accessible name; the swell is decoration and " \
          "the dock works the same without it.",
          "Leave room around the dock for the swell: items scale past their box without moving others."
        ].freeze

        use_behavior :pointer
        use_behavior :spring

        use_stimulus do
          on :root do
            controller :dock, if: :animate do
              register
              value :magnification
              value :distance
              value :spring
            end
          end
        end

        motion_options spring: :snappy
        option :label, :string, doc: "The navigation's accessible name."
        option :orientation, :symbol, default: :horizontal, doc: "Which way the dock runs."
        option :magnification, :float, default: 1.5, doc: "The scale of the item right under the pointer."
        option :distance, :integer, default: 120, doc: "How far, in pixels, the swell reaches from the pointer."

        validates :orientation, inclusion: { in: ORIENTATIONS }

        part "dock", "The row of items; the swell reaches across it",
             states: { "data-orientation" => { condition: "always - which way the dock runs",
                                               values: ORIENTATIONS.map(&:to_s) } }

        def before_render
          ensure_content!
          ensure_within!(:magnification, 1.0..3.0)
          ensure_within!(:distance, 20..600)
        end

        def call
          tag.nav(content, **root_attributes)
        end

        def root_attributes
          super({ "aria-label" => label.presence, "data-orientation" => orientation }.compact)
        end
      end
    end
  end
end
