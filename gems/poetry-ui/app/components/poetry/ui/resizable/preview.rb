# frozen_string_literal: true

module Poetry
  module Ui
    module Resizable
      # The Resizable preview: the two-pane split (with the grip) and a
      # nested two-axis layout.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(grip: true, class: "h-48 max-w-md rounded-lg border") do |group|
            group.with_panel(default_size: 25, min_size: 15) do
              tag.div("Sidebar", class: "flex h-full items-center justify-center p-6 text-sm")
            end
            group.with_panel do
              tag.div("Content", class: "flex h-full items-center justify-center p-6 text-sm")
            end
          end
        end

        def nested
          render_component(class: "h-48 max-w-md rounded-lg border") do |group|
            group.with_panel(default_size: 40) do
              tag.div("Left", class: "flex h-full items-center justify-center p-6 text-sm")
            end
            group.with_panel do
              embed(nested_group)
            end
          end
        end

        private

        def nested_group
          Poetry::Ui::Resizable::Component.new(direction: :vertical).tap do |group|
            group.with_panel { tag.div("Top", class: "flex h-full items-center justify-center p-6 text-sm") }
            group.with_panel { tag.div("Bottom", class: "flex h-full items-center justify-center p-6 text-sm") }
          end
        end
      end
    end
  end
end
