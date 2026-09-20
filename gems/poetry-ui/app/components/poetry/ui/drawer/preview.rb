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

        def top_sheet
          render_component(direction: :up) do |drawer|
            drawer.with_trigger { "Open notice" }
            drawer.with_title { "Service notice" }
            "Swipe up to dismiss."
          end
        end

        def left_edge
          render_component(direction: :left) do |drawer|
            drawer.with_trigger { "Open navigation" }
            drawer.with_title { "Navigate" }
            "Swipe left to dismiss."
          end
        end

        # modal: false keeps the page interactive behind the drawer -
        # Esc rides its own keydown exit (a non-modal dialog never fires
        # cancel).
        def non_modal
          render_component(modal: false) do |drawer|
            drawer.with_trigger { "Open player" }
            drawer.with_title { "Now playing" }
            "The page stays interactive behind this drawer."
          end
        end

        # snap_points: the swipe physics settle at fractional heights.
        def with_snap_points
          render_component(snap_points: [0.4, 1]) do |drawer|
            drawer.with_trigger { "Open details" }
            drawer.with_title { "Details" }
            "Drag the handle - the sheet settles at 40% or full height."
          end
        end
      end
    end
  end
end
