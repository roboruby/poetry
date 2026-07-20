# frozen_string_literal: true

module Poetry
  module Ui
    module Timeline
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component do |timeline|
            timeline.with_item(title: "Order placed", time: "Mar 15, 09:12", completed: true) do
              "Payment authorized and inventory reserved."
            end
            timeline.with_item(title: "Packed", time: "Mar 15, 14:03", completed: true) do
              "Two parcels sealed at dock B."
            end
            timeline.with_item(title: "In transit", time: "Mar 16") do
              "Handed to the carrier - estimated delivery Thursday."
            end
            timeline.with_item(title: "Delivered")
          end
        end

        # The order tracker: steps left-to-right, progress recoloring the
        # rail up to the current step.
        def horizontal
          render_component(orientation: :horizontal) do |timeline|
            timeline.with_item(title: "Ordered", time: "Mar 15", completed: true)
            timeline.with_item(title: "Packed", time: "Mar 15", completed: true)
            timeline.with_item(title: "Shipped", time: "Mar 16")
            timeline.with_item(title: "Delivered")
          end
        end

        # icon: swaps the dot for a glyph - the indicator stays decorative.
        def with_icons
          render_component do |timeline|
            timeline.with_item(title: "Repository created", time: "Jun 2",
                               icon: :"git-branch", completed: true) do
              "poetry-ui scaffolded from the gem template."
            end
            timeline.with_item(title: "First deploy", time: "Jun 4",
                               icon: :rocket, completed: true) do
              "Shipped to staging behind the feature flag."
            end
            timeline.with_item(title: "Incident opened", time: "Jun 9", icon: :"triangle-alert") do
              "Elevated 5xx rate on checkout - rolled back in 12 minutes."
            end
          end
        end

        # Titles alone: the anatomy holds without times or descriptions.
        def titles_only
          render_component do |timeline|
            timeline.with_item(title: "Draft", completed: true)
            timeline.with_item(title: "In review")
            timeline.with_item(title: "Published")
          end
        end
      end
    end
  end
end
