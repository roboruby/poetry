# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module NavigationMenu
      class ComponentTest < ViewComponent::TestCase
        def render_nav(**options)
          render_inline(Component.new(label: "Main", **options)) do |nav|
            nav.with_item("Products", value: "products") { "panel links" }
            nav.with_link("Docs", href: "/docs")
          end
        end

        def test_the_bar_is_a_named_nav_landmark_in_viewport_false_mode
          html = render_nav

          nav = html.css("nav").first

          assert_equal "Main", nav["aria-label"]
          assert_equal "false", nav["data-viewport"], "the popup-chrome mode marker"
          assert_includes nav["data-controller"], "poetry--core--navigation-menu"
          assert_includes nav["data-action"], "keydown->poetry--core--navigation-menu#keydown"
          assert_includes nav["data-action"], "focusout->poetry--core--navigation-menu#focusLeft"
        end

        def test_a_panel_item_wires_the_disclosure_not_a_menu
          html = render_nav

          trigger = html.css('button[data-slot="navigation-menu-trigger"]').first

          assert_equal "false", trigger["aria-expanded"]
          panel = html.css('[data-slot="navigation-menu-content"]').first

          assert_equal trigger["aria-controls"], panel["id"]
          assert panel["hidden"], "server-rendered closed"
          assert panel["data-closed"]
          assert_empty html.css("[role=menu], [role=menuitem]"), "a disclosure bar, never menu roles"
          item = html.css('[data-slot="navigation-menu-item"]').first

          assert_includes item["data-action"], "pointerenter->poetry--core--navigation-menu#scheduleOpen"
          assert_includes trigger["data-action"], "click->poetry--core--navigation-menu#toggle"
        end

        def test_a_top_level_link_is_a_real_destination_with_trigger_styling
          html = render_nav

          link = html.css('a[data-slot="navigation-menu-link"]').first

          assert_equal "/docs", link["href"]
          assert_includes link["class"], "h-9", "wears the trigger style"
          docs_item = html.css('[data-slot="navigation-menu-item"]').last

          assert_nil docs_item["data-action"], "link items schedule nothing"
        end

        def test_the_nav_requires_a_label_and_entries
          assert_raises(ArgumentError) do
            render_inline(Component.new) { |nav| nav.with_link("Docs", href: "/docs") }
          end
          assert_raises(ArgumentError) { render_inline(Component.new(label: "Main")) }
        end

        def test_an_item_needs_a_panel_or_an_href
          assert_raises(ArgumentError) do
            render_inline(Component.new(label: "Main")) { |nav| nav.with_item("Broken") }
          end
        end
      end
    end
  end
end
