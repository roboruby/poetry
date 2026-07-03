# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module ContextMenu
      class ComponentTest < ViewComponent::TestCase
        # The class strings carry ">" ([&_svg...] selectors) - attribute
        # assertions go through Nokogiri, never [^>]* regexes across
        # class attributes (the Accordion test hazard).
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def render_menu(**, &block)
          block ||= lambda { |menu|
            menu.with_trigger { "Surface" }
            menu.with_item { "Rename" }
            menu.with_item { "Duplicate" }
          }
          render_inline(Component.new(**), &block).to_html
        end

        def test_root_hosts_all_three_controllers_on_one_attributes_instance
          html = render_menu
          root = doc(html).css('[data-slot="context-menu"]').first

          assert_equal "context_menu", root["data-component"]
          # ONE shared Attributes instance: token-concatenated, not overwritten.
          assert_equal "poetry--core--context-menu poetry--core--menu poetry--core--popper",
                       root["data-controller"]
          assert_equal "700", root["data-poetry--core--context-menu-long-press-delay-value"]
          assert_equal "false", root["data-poetry--core--context-menu-disabled-value"]
          assert_equal "false", root["data-poetry--core--menu-open-value"]
          assert_equal "true", root["data-poetry--core--menu-modal-value"]
          # side right / align start / side_offset 2 are FORCED (no API).
          assert_equal "right", root["data-poetry--core--popper-side-value"]
          assert_equal "start", root["data-poetry--core--popper-align-value"]
          assert_equal "2", root["data-poetry--core--popper-side-offset-value"]
          assert_equal "true", root["data-poetry--core--popper-avoid-collisions-value"]
        end

        def test_trigger_is_a_role_less_surface_not_a_button
          html = render_menu
          trigger = doc(html).css('[data-slot="context-menu-trigger"]').first
          content = doc(html).css('[data-slot="context-menu-content"]').first

          assert_equal "span", trigger.name, "the surface defaults to an inline span"
          # The DELTA, asserted not just unasserted: the surface is NOT a widget.
          assert_nil trigger["aria-haspopup"]
          assert_nil trigger["aria-expanded"]
          assert_nil trigger["role"]
          assert_nil trigger["tabindex"]
          assert_equal "closed", trigger["data-state"]
          assert_includes trigger["style"], "-webkit-touch-callout: none"
          assert_equal content["id"], trigger["aria-controls"]
          assert_equal "anchor", trigger["data-poetry--core--popper-target"]
          assert_includes trigger["data-action"], "contextmenu->poetry--core--context-menu#open"
          assert_includes trigger["data-action"], "pointerdown->poetry--core--context-menu#pressStart"
          assert_includes trigger["data-action"], "pointermove->poetry--core--context-menu#pressCancel"
          assert_includes trigger["data-action"], "pointerup->poetry--core--context-menu#pressCancel"
          assert_includes trigger["data-action"], "pointercancel->poetry--core--context-menu#pressCancel"
        end

        def test_trigger_surface_is_polymorphic_and_merges_style
          html = render_menu do |menu|
            menu.with_trigger(tag: :div, style: "min-height: 150px", class: "border-dashed") { "Card" }
            menu.with_item { "Open" }
          end
          trigger = doc(html).css('[data-slot="context-menu-trigger"]').first

          assert_equal "div", trigger.name
          assert_includes trigger["style"], "-webkit-touch-callout: none"
          assert_includes trigger["style"], "min-height: 150px"
          assert_includes trigger["class"], "border-dashed"
        end

        def test_content_is_a_closed_labelled_menu_with_no_static_layer_controllers
          html = render_menu
          content = doc(html).css('[data-slot="context-menu-content"]').first

          assert_equal "menu", content["role"]
          assert_equal "vertical", content["aria-orientation"]
          # No aria-labelledby to a non-widget surface: the i18n fallback names the menu.
          assert_nil content["aria-labelledby"]
          assert_equal "Context menu", content["aria-label"]
          assert_equal "-1", content["tabindex"]
          assert_equal "closed", content["data-state"]
          assert content.key?("hidden"), "closed content is hidden (truthful server render)"
          assert_equal "right", content["data-side"]
          assert_equal "start", content["data-align"]
          assert_equal "content", content["data-poetry--core--popper-target"]
          # The layer controllers are token-ACTIVATED by the menu controller on open.
          assert_nil content["data-controller"]
        end

        def test_label_option_names_the_menu
          html = render_menu(label: "Row actions")
          content = doc(html).css('[data-slot="context-menu-content"]').first

          assert_equal "Row actions", content["aria-label"]
        end

        def test_open_state_is_server_rendered
          html = render_menu(open: true)
          content = doc(html).css('[data-slot="context-menu-content"]').first
          trigger = doc(html).css('[data-slot="context-menu-trigger"]').first

          assert_equal "open", content["data-state"]
          refute content.key?("hidden")
          assert_equal "open", trigger["data-state"]
          assert_nil trigger["aria-expanded"], "open state never introduces ARIA onto the surface"
        end

        def test_disabled_surface_keeps_no_inert_markup_only_the_styling_hook
          html = render_menu(disabled: true)
          root = doc(html).css('[data-slot="context-menu"]').first
          trigger = doc(html).css('[data-slot="context-menu-trigger"]').first

          # disabled stands the JS handlers down (native menu passthrough) -
          # the wiring stays; only the value + the styling hook flip.
          assert_equal "true", root["data-poetry--core--context-menu-disabled-value"]
          assert trigger.key?("data-disabled")
          assert_includes trigger["data-action"], "contextmenu->poetry--core--context-menu#open"
        end

        def test_focusable_surface_mode_is_opt_in
          html = render_menu(focusable_surface: true)
          trigger = doc(html).css('[data-slot="context-menu-trigger"]').first

          assert_equal "0", trigger["tabindex"]
          assert_equal "Shift+F10", trigger["aria-keyshortcuts"]
          assert_nil trigger["role"], "focusable-surface mode still adds no role"
          assert_nil trigger["aria-haspopup"]
        end

        def test_long_press_delay_is_an_option
          html = render_menu(long_press_delay: 500)
          root = doc(html).css('[data-slot="context-menu"]').first

          assert_equal "500", root["data-poetry--core--context-menu-long-press-delay-value"]
        end

        def test_items_are_role_menuitem_divs_in_the_collection
          html = render_menu
          item = doc(html).css('[data-slot="context-menu-item"]').first

          assert_equal "div", item.name, "menu items are divs, not buttons (APG/Radix-exact)"
          assert_equal "menuitem", item["role"]
          assert_equal "-1", item["tabindex"]
          assert item.key?("data-poetry-collection-item")
          assert_equal "default", item["data-variant"]
          assert_equal "click->poetry--core--menu#activate", item["data-action"]
        end

        def test_item_options_variant_inset_disabled_shortcut
          html = render_menu do |menu|
            menu.with_trigger { "Surface" }
            menu.with_item(variant: :destructive) { "Delete" }
            menu.with_item(inset: true, shortcut: "⌘R") { "Reload" }
            menu.with_item(disabled: true) { "Forward" }
          end
          destructive, inset, disabled = doc(html).css('[data-slot="context-menu-item"]').to_a
          shortcut = doc(html).css('[data-slot="context-menu-shortcut"]').first

          assert_equal "destructive", destructive["data-variant"]
          assert_equal "true", inset["data-inset"]
          assert_equal "true", disabled["aria-disabled"]
          assert disabled.key?("data-disabled")
          assert_equal "⌘R", shortcut.text
          assert_equal "true", shortcut["aria-hidden"], "shortcut is a visual hint only (family rule)"
        end

        def test_unknown_item_variant_raises
          assert_raises(ArgumentError) do
            render_menu do |menu|
              menu.with_trigger { "Surface" }
              menu.with_item(variant: :sparkly) { "Nope" }
            end
          end
        end

        def test_checkbox_and_radio_items_write_aria_checked_and_data_state_together
          html = render_menu do |menu|
            menu.with_trigger { "Surface" }
            menu.with_checkbox_item(checked: true, close_on_select: false) { "Show Bookmarks" }
            menu.with_radio_group(value: "pedro") do |group|
              group.with_radio_item(value: "pedro") { "Pedro" }
              group.with_radio_item(value: "colm") { "Colm" }
            end
          end
          checkbox = doc(html).css('[data-slot="context-menu-checkbox-item"]').first
          group = doc(html).css('[data-slot="context-menu-radio-group"]').first
          pedro, colm = group.css('[data-slot="context-menu-radio-item"]').to_a

          assert_equal "menuitemcheckbox", checkbox["role"]
          assert_equal(%w[true checked], [checkbox["aria-checked"], checkbox["data-state"]])
          assert_equal "false", checkbox["data-close-on-select"]
          assert_equal "group", group["role"]
          assert_equal "pedro", group["data-value"]
          assert_equal(%w[true checked], [pedro["aria-checked"], pedro["data-state"]])
          assert_equal(%w[false unchecked], [colm["aria-checked"], colm["data-state"]])
          assert_predicate group.css('[data-slot="context-menu-item-indicator"]'), :any?
        end

        def test_duplicate_radio_values_raise
          error = assert_raises(ArgumentError) do
            render_menu do |menu|
              menu.with_trigger { "Surface" }
              menu.with_radio_group(value: "a") do |group|
                group.with_radio_item(value: "a") { "A" }
                group.with_radio_item(value: "a") { "A again" }
              end
            end
          end

          assert_includes error.message, "duplicate ContextMenu radio value"
        end

        def test_label_separator_and_group_parts
          html = render_menu do |menu|
            menu.with_trigger { "Surface" }
            menu.with_label(inset: true) { "People" }
            menu.with_group do |group|
              group.with_item { "Open" }
            end
            menu.with_separator
            menu.with_item { "Rename" }
          end
          fragment = doc(html)
          label = fragment.css('[data-slot="context-menu-label"]').first
          separator = fragment.css('[data-slot="context-menu-separator"]').first
          group = fragment.css('[data-slot="context-menu-group"]').first

          assert_equal "People", label.text
          assert_equal "true", label["data-inset"]
          assert_nil label["role"]
          assert_equal "separator", separator["role"]
          assert_equal "group", group["role"]
          assert_predicate group.css('[data-slot="context-menu-item"]'), :any?
        end

        def test_submenu_renders_a_nested_popper_root_with_its_own_aria_pair
          html = render_menu do |menu|
            menu.with_trigger { "Surface" }
            menu.with_sub do |sub|
              sub.with_trigger(inset: true) { "More Tools" }
              sub.with_item { "Developer Tools" }
            end
          end
          sub = doc(html).css('[data-slot="context-menu-sub"]').first
          sub_trigger = sub.css('[data-slot="context-menu-sub-trigger"]').first
          sub_content = sub.css('[data-slot="context-menu-sub-content"]').first

          assert_equal "poetry--core--popper", sub["data-controller"]
          assert_equal "right", sub["data-poetry--core--popper-side-value"]
          assert_equal "start", sub["data-poetry--core--popper-align-value"]

          # Sub-triggers ARE menuitems - the widget ARIA lives here, not on the surface.
          assert_equal "menuitem", sub_trigger["role"]
          assert_equal "menu", sub_trigger["aria-haspopup"]
          assert_equal "false", sub_trigger["aria-expanded"]
          assert_equal sub_content["id"], sub_trigger["aria-controls"]
          assert_equal "true", sub_trigger["data-inset"]
          assert_predicate sub_trigger.css("svg"), :any?, "the trailing chevron ships built in"

          assert_equal "menu", sub_content["role"]
          assert_equal sub_trigger["id"], sub_content["aria-labelledby"]
          assert sub_content.key?("hidden")
          assert_nil sub_content["data-controller"], "sub layer controllers are runtime-activated"
        end

        def test_rtl_flips_the_submenu_side_and_sets_dir
          html = render_menu(dir: :rtl) do |menu|
            menu.with_trigger { "Surface" }
            menu.with_sub do |sub|
              sub.with_trigger { "More" }
              sub.with_item { "Import" }
            end
          end
          root = doc(html).css('[data-slot="context-menu"]').first
          sub = doc(html).css('[data-slot="context-menu-sub"]').first

          assert_equal "rtl", root["dir"]
          assert_equal "left", sub["data-poetry--core--popper-side-value"]
        end

        def test_required_slot_guards
          assert_raises(ArgumentError, "missing trigger") do
            render_inline(Component.new) { |menu| menu.with_item { "Rename" } }
          end
          assert_raises(ArgumentError, "missing items") do
            render_inline(Component.new) { |menu| menu.with_trigger { "Surface" } }
          end
        end

        def test_source_exact_classes_land_on_content_label_and_sub_trigger
          html = render_menu do |menu|
            menu.with_trigger { "Surface" }
            menu.with_label { "People" }
            menu.with_sub do |sub|
              sub.with_trigger { "More" }
              sub.with_item { "Import" }
            end
          end

          assert_includes html, "max-h-(--radix-context-menu-content-available-height)"
          assert_includes html, "origin-(--radix-context-menu-content-transform-origin)"
          # The context deltas vs the dropdown dictionary:
          label = doc(html).css('[data-slot="context-menu-label"]').first
          sub_trigger = doc(html).css('[data-slot="context-menu-sub-trigger"]').first

          assert_includes label["class"], "text-foreground"
          refute_includes sub_trigger["class"], "gap-2", "the context sub-trigger omits gap-2 (source-exact)"
        end
      end
    end
  end
end
