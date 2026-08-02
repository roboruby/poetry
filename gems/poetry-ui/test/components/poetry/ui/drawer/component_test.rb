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
          # The corner/edge chrome rides the per-direction theme rule; the
          # movement-axis var mapping stays inline (mechanism).
          assert_includes dialog["class"], "cn-drawer-direction-right"
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

        def test_the_root_wrapper_never_wears_the_direction_chrome
          html = render_drawer(class: "my-drawer")

          root = html.css('[data-slot="drawer"]').first
          root_classes = (root["class"] || "").split

          # The resolver renders the direction variant at the dictionary
          # root; it belongs to the <dialog> only. On the in-flow wrapper
          # the themed border drew a line across the docs mounts and
          # w-full broke their centering (2026-08-01 browser pass).
          assert_empty root_classes.grep(/drawer-direction|w-full|mt-auto/),
                       "direction chrome leaked onto the non-visual root"
          assert_includes root_classes, "my-drawer", "caller classes still land on the root"
          dialog_classes = html.css("dialog").first["class"].split

          assert_includes dialog_classes, "cn-drawer-direction-down"
          assert_includes dialog_classes, "mt-auto"
        end

        def test_the_direction_geometry_reads_the_theme_inset
          dialog = render_drawer(direction: :right).css("dialog").first["class"]

          # Upstream's --drawer-inset contract (default 0px = flush): a
          # theme floats the drawer off the viewport edges by setting the
          # var (rhea/mira/luma/maia ship --spacing(2), like their source
          # styles); the closed transform travels the extra inset so the
          # exit still clears the viewport.
          assert_includes dialog, "mr-(--drawer-inset,0px)"
          assert_includes dialog, "my-(--drawer-inset,0px)"
          assert_includes dialog,
                          "[--closed-transform:translate3d(calc(100%+var(--drawer-inset,0px)+2px),0,0)]"
        end

        def test_bottom_sheets_size_to_content_not_the_max_height_cap
          down = render_drawer.css("dialog").first["class"].split

          # h-fit, never h-auto: the UA :modal sets top:0 AND bottom:0, and
          # an abspos box with both insets and height:auto SOLVES height to
          # fill (CSS2 10.6.4) - h-auto blew every bottom sheet up to its
          # max-h cap (2026-08-01 browser pass, one-line body 557px tall).
          assert_includes down, "h-fit"
          refute_includes down, "h-auto"
          right = render_drawer(direction: :right).css("dialog").first["class"].split

          assert_includes right, "h-auto", "edge panels DO fill the viewport axis"
        end

        def test_non_modal_restates_the_top_layer_positioning_and_wires_esc
          html = render_drawer(modal: false, direction: :right)

          root = html.css('[data-slot="drawer"]').first

          assert_equal "false", root["data-poetry--core--drawer-modal-value"]
          dialog = html.css("dialog").first
          classes = dialog["class"].split

          # show() skips the top layer, so the UA :modal fixed/inset:0
          # must be explicit for the direction margins to keep working.
          assert_includes classes, "fixed"
          assert_includes classes, "inset-0"
          assert_includes classes, "z-50"
          # No cancel event outside the top layer - Esc rides keydown.
          assert_includes dialog["data-action"], "keydown->poetry--core--drawer#escapeClose"
        end

        def test_modal_drawers_keep_the_top_layer_contract_unchanged
          html = render_drawer
          dialog = html.css("dialog").first

          refute_includes dialog["class"].split, "fixed"
          refute_includes dialog["data-action"], "escapeClose"
          assert_equal "true", html.css('[data-slot="drawer"]').first["data-poetry--core--drawer-modal-value"]
        end

        def test_snap_points_stamp_the_sizing_attribute_and_the_value
          html = render_drawer(snap_points: ["31rem", 1])

          dialog = html.css("dialog").first

          assert dialog.key?("data-snap-points"), "the dictionary's full-height sizing hook"
          root = html.css('[data-slot="drawer"]').first

          assert_equal '["31rem",1]', root["data-poetry--core--drawer-snap-points-value"]
        end

        def test_snap_points_teach_their_bounds
          error = assert_raises(ArgumentError) do
            render_drawer(snap_points: [0.4], direction: :right)
          end

          assert_match(/:down only/, error.message)
          error = assert_raises(ArgumentError) { render_drawer(snap_points: [0, "31vh"]) }

          assert_match(/fractions in \(0, 1\]/, error.message)
        end

        def test_plain_drawers_carry_no_snap_surface
          html = render_drawer
          dialog = html.css("dialog").first

          refute dialog.key?("data-snap-points")
          assert_nil html.css('[data-slot="drawer"]').first["data-poetry--core--drawer-snap-points-value"]
        end

        def test_the_parents_show_close_button_is_hidden_from_the_contract
          # A Drawer renders no corner X (vaul parity), so the inherited
          # Dialog option must not project - a listed option the template
          # ignores would be a contract lie.
          refute_includes Component.option_attributes, :show_close_button
          assert_includes Poetry::Ui::Sheet::Component.option_attributes, :show_close_button
        end
      end
    end
  end
end
