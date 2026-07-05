# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Drawer
      class ComponentTest < ViewComponent::TestCase
        def render_drawer(**, &block)
          block ||= lambda { |drawer|
            drawer.with_trigger { "Open" }
            drawer.with_title { "Move goal" }
            "body"
          }
          render_inline(Component.new(**), &block)
        end

        def test_the_drawer_is_a_native_dialog_on_the_drawer_controller
          html = render_drawer

          root = html.css('[data-slot="drawer"]').first

          assert_includes root["data-controller"], "poetry--core--drawer"
          assert_equal "down", root["data-poetry--core--drawer-direction-value"]
          dialog = html.css("dialog").first

          assert_equal "drawer-content", dialog["data-slot"]
          assert dialog["data-closed"], "server-rendered closed"
          assert_equal dialog["aria-labelledby"], html.css("h2").first["id"]
        end

        def test_the_swipe_wiring_and_vocabulary_land_on_the_dialog
          html = render_drawer

          dialog = html.css("dialog").first

          assert_equal "down", dialog["data-swipe-direction"]
          %w[pointerdown->poetry--core--drawer#swipeStart pointermove->poetry--core--drawer#swipeMove
             pointerup->poetry--core--drawer#swipeEnd pointercancel->poetry--core--drawer#swipeCancel
             cancel->poetry--core--drawer#close].each do |action|
            assert_includes dialog["data-action"], action
          end
          assert_includes dialog["class"], "data-swiping:duration-0"
          assert_includes dialog["class"], "data-ending-style:transform-(--closed-transform)"
        end

        def test_the_trigger_opens_the_drawer_controller_not_the_dialog_one
          html = render_drawer

          trigger = html.css("button").first

          assert_includes trigger["data-action"], "poetry--core--drawer#open",
                          "the inherited trigger slot must wire the SUBCLASS controller"
          assert_not_includes trigger["data-action"].to_s, "poetry--core--dialog#open"
        end

        def test_direction_maps_the_edge_chrome_and_movement_axis
          html = render_drawer(direction: :right)

          dialog = html.css("dialog").first

          assert_equal "right", dialog["data-swipe-direction"]
          assert_includes dialog["class"], "rounded-l-xl"
          assert_includes dialog["class"], "[--translate-x:var(--drawer-swipe-movement-x,0px)]"
        end

        def test_the_swipe_handle_is_opt_in_and_decorative
          plain = render_drawer

          assert_empty plain.css('[data-slot="drawer-swipe-handle"]')

          with_handle = render_drawer(show_swipe_handle: true)
          handle = with_handle.css('[data-slot="drawer-swipe-handle"]').first

          assert_equal "true", handle["aria-hidden"]
          assert_includes handle["class"], "touch-none", "the browser must not steal the drag for scroll"
        end

        def test_a_drawer_requires_its_title
          assert_raises(ArgumentError) do
            render_inline(Component.new) { |drawer| drawer.with_trigger { "Open" } }
          end
        end
      end
    end
  end
end
