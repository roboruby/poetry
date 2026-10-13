# frozen_string_literal: true

module Poetry
  module Motion
    module LayoutGroup
      # A region where elements that share a data-layout-id are one thing in
      # different places: an active-tab indicator, a selected-item
      # highlight. When the visible one changes, it slides and resizes from
      # where the last one was. Mark every candidate with the same
      # data-layout-id and show only the current one; the server renders it
      # in place.
      #
      # @example A highlight that follows the checked item
      #   <%= poetry_layout_group do %>
      #     <%= poetry_toggle_group(type: :single, default: "week") do |group| %>
      #       <% %w[day week month].each do |range| %>
      #         <% group.with_item(value: range) do %>
      #           <span data-slot="layout-group-item" data-layout-id="range"
      #                 class="hidden in-aria-checked:block ..."></span><%= range %>
      #         <% end %>
      #       <% end %>
      #     <% end %>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Motion::Options

        requires_content "the elements that carry data-layout-id"

        AGENT_RULES = [
          "Show exactly one element per data-layout-id at a time; the group animates the newly visible " \
          "one from the old one's box. Hide the others with display, never visibility or opacity."
        ].freeze

        use_behavior :animate

        use_stimulus do
          on :root do
            controller :layout_group, if: :animate do
              register
              value :duration, from: :duration_ms
            end
          end
        end

        motion_options duration: :normal

        part "layout-group", "The region whose data-layout-id elements move between places"
        part "layout-group-item", "One place a moving element can be; the visible one is current",
             states: { "data-layout-id" => "always - the id every place of one moving element shares" }

        def before_render
          ensure_content!
          ensure_motion_options!
        end

        def call
          tag.div(content, **root_attributes)
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
