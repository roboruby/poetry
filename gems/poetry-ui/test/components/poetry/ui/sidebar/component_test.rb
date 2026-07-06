# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Sidebar
      class ComponentTest < ViewComponent::TestCase
        def render_shell(**options)
          render_inline(Component.new(**options)) do |shell|
            shell.with_nav { "nav" }
            shell.with_inset { "page" }
          end
        end

        def test_the_shell_wires_the_controller_and_carries_the_width_vars
          html = render_shell

          wrapper = html.css('[data-slot="sidebar-wrapper"]').first

          assert_includes wrapper["data-controller"], "poetry--core--sidebar"
          assert_includes wrapper["style"], "--sidebar-width: 16rem"
          assert_includes wrapper["style"], "--sidebar-width-icon: 3rem"
          assert_equal "true", wrapper["data-poetry--core--sidebar-open-value"]
        end

        def test_the_peer_carries_the_server_rendered_state_as_the_controller_target
          html = render_shell(collapsible: :icon, side: :right, variant: :floating)

          peer = html.css('[data-slot="sidebar"]').first

          assert_equal "expanded", peer["data-state"], "open by default"
          assert_equal "", peer["data-collapsible"], "the mode is empty while expanded"
          assert_equal "right", peer["data-side"]
          assert_equal "floating", peer["data-variant"]
          assert_equal "sidebar", peer["data-poetry--core--sidebar-target"]
        end

        def test_a_server_collapsed_shell_stamps_the_mode
          html = render_shell(open: false, collapsible: :icon)

          peer = html.css('[data-slot="sidebar"]').first

          assert_equal "collapsed", peer["data-state"]
          assert_equal "icon", peer["data-collapsible"], "the mode rides data-collapsible while collapsed"
          assert_equal "false", html.css('[data-slot="sidebar-wrapper"]').first["data-poetry--core--sidebar-open-value"]
        end

        def test_the_mobile_sheet_renders_empty_with_the_dom_move_wiring
          html = render_shell(side: :left)

          dialog = html.css('dialog[data-slot="sidebar-mobile"]').first

          assert dialog, "the mobile <dialog> ships with the shell"
          assert_equal "true", dialog["data-mobile"]
          assert_equal "left", dialog["data-side"]
          assert_includes dialog["style"], "--sidebar-width: 18rem"
          assert_equal "mobileDialog", dialog["data-poetry--core--sidebar-target"]
          assert_includes dialog["data-action"], "cancel->poetry--core--sidebar#closeMobile"
          assert_includes dialog["data-action"], "click->poetry--core--sidebar#mobileBackdropClose"
          assert_includes dialog["class"], "md:hidden"

          # Rendered EMPTY - the controller adopts the nav on open (
          # DOM-move: one render, no duplicate ids).
          inner = dialog.css('[data-slot="sidebar-mobile-inner"]').first

          assert_equal "mobileInner", inner["data-poetry--core--sidebar-target"]
          assert_empty inner.text.strip
          assert_equal "inner",
                       html.css('[data-slot="sidebar-inner"]').first["data-poetry--core--sidebar-target"]

          # The sr-only accessible name (upstream parity).
          assert_equal dialog.css("h2").first["id"], dialog["aria-labelledby"]
        end

        def test_the_inset_is_a_main_landmark_holding_the_page
          html = render_shell

          inset = html.css('main[data-slot="sidebar-inset"]').first

          assert inset, "the inset is a <main>"
          assert_equal "page", inset.text.strip
        end

        def test_the_trigger_toggles_the_controller
          html = render_inline(Component.new) do |shell|
            shell.with_nav { "nav" }
            shell.with_inset { vc_test_controller.view_context.poetry_sidebar_trigger }
          end

          trigger = html.css('[data-slot="sidebar-trigger"]').first

          assert_includes trigger["data-action"], "click->poetry--core--sidebar#toggle"
          assert_equal "Toggle Sidebar", trigger["aria-label"]
        end

        def test_a_menu_button_link_marks_the_active_route
          html = render_inline(Component.new) do |shell|
            shell.with_nav do
              vc_test_controller.view_context.poetry_sidebar_menu do
                vc_test_controller.view_context.poetry_sidebar_menu_item do
                  vc_test_controller.view_context.poetry_sidebar_menu_button(href: "/dashboard", active: true) do
                    "Dashboard"
                  end
                end
              end
            end
          end

          button = html.css('[data-slot="sidebar-menu-button"]').first

          assert_equal "a", button.name, "a href renders a real link"
          assert_equal "/dashboard", button["href"]
          assert_equal "page", button["aria-current"]
          assert button.key?("data-active"), "data-active styles the current route"
        end

        def test_the_shell_requires_the_nav_column
          assert_raises(ArgumentError) do
            render_inline(Component.new) { |shell| shell.with_inset { "page" } }
          end
        end
      end
    end
  end
end
