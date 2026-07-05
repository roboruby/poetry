# frozen_string_literal: true

module Poetry
  module Ui
    module Drawer
      # The Drawer preview: the bottom sheet with its grab handle (the
      # gesture's discoverability affordance), and a right-edge panel.
      # Previews render CLOSED (the trigger page, the Dialog convention);
      # the dommy tier drives the open/swipe behavior.
      class Preview < Poetry::Core::Preview::Base
        def default
          render_component(show_swipe_handle: true) do |drawer|
            drawer.with_trigger { "Open drawer" }
            drawer.with_title { "Move goal" }
            drawer.with_description { "Set your daily activity goal." }
            drawer.with_footer do
              embed(Poetry::Ui::Button::Component.new.with_content("Submit"))
            end
            "Drag the handle down to dismiss."
          end
        end

        def right_edge
          render_component(direction: :right) do |drawer|
            drawer.with_trigger { "Open panel" }
            drawer.with_title { "Filters" }
            "Swipe right to dismiss."
          end
        end
      end
    end
  end
end
