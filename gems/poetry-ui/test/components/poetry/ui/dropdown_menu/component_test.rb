# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module DropdownMenu
      class ComponentTest < ViewComponent::TestCase
        # The class strings carry ">" ([&_svg...] selectors) - attribute
        # assertions go through Nokogiri, never [^>]* regexes across
        # class attributes (the Accordion test hazard).
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def render_menu(**, &block)
          block ||= lambda { |menu|
            menu.with_trigger(variant: :outline) { "Open" }
            menu.with_item { "Profile" }
            menu.with_item { "Billing" }
          }
          render_inline(Component.new(**), &block).to_html
        end

        def test_root_hosts_both_controllers_on_one_attributes_instance
          html = render_menu
          root = doc(html).css('[data-slot="dropdown-menu"]').first

          assert_equal "dropdown_menu", root["data-component"]
          # ONE shared Attributes instance: token-concatenated, not overwritten.
          assert_equal "poetry--core--menu poetry--core--popper", root["data-controller"]
          assert_equal "false", root["data-poetry--core--menu-open-value"]
          assert_equal "true", root["data-poetry--core--menu-modal-value"]
          assert_equal "false", root["data-poetry--core--menu-loop-value"]
          assert_equal "bottom", root["data-poetry--core--popper-side-value"]
          assert_equal "center", root["data-poetry--core--popper-align-value"]
          assert_equal "4", root["data-poetry--core--popper-side-offset-value"]
          assert_equal "true", root["data-poetry--core--popper-avoid-collisions-value"]
        end

        def test_trigger_is_an_aria_wired_menu_button
          html = render_menu
          trigger = doc(html).css('button[data-slot="dropdown-menu-trigger"]').first
          content = doc(html).css('[data-slot="dropdown-menu-content"]').first

          assert_equal "menu", trigger["aria-haspopup"]
          assert_equal "false", trigger["aria-expanded"]
          assert_equal content["id"], trigger["aria-controls"]
          refute trigger.key?("data-popup-open"), "closed trigger carries NO state attribute (absence IS the state)"
          assert_equal "anchor", trigger["data-poetry--core--popper-target"]
          assert_includes trigger["data-action"], "click->poetry--core--menu#toggle"
          assert_includes trigger["data-action"], "keydown->poetry--core--menu#triggerKeydown"
          # The composed poetry Button keeps its own identity (demo parity).
          assert_equal "button", trigger["data-component"]
        end

        def test_content_is_a_closed_labelled_menu_with_no_static_layer_controllers
          html = render_menu
          content = doc(html).css('[data-slot="dropdown-menu-content"]').first
          trigger = doc(html).css('[data-slot="dropdown-menu-trigger"]').first

          assert_equal "menu", content["role"]
          assert_equal "vertical", content["aria-orientation"]
          assert_equal trigger["id"], content["aria-labelledby"]
          assert_equal "-1", content["tabindex"]
          assert content.key?("data-closed"), "mounted-closed popup carries bare data-closed"
          refute content.key?("data-open")
          assert content.key?("hidden"), "closed content is hidden (truthful server render)"
          assert_equal "content", content["data-poetry--core--popper-target"]
          # The layer controllers (focus-scope/dismissable/roving-focus) are
          # token-ACTIVATED by the menu controller on open - a static trap
          # on a hidden menu would steal focus at page load.
          assert_nil content["data-controller"]
        end

        def test_open_state_is_server_rendered
          html = render_menu(open: true)
          content = doc(html).css('[data-slot="dropdown-menu-content"]').first
          trigger = doc(html).css('[data-slot="dropdown-menu-trigger"]').first

          assert content.key?("data-open"), "open popup carries bare data-open"
          refute content.key?("data-closed")
          refute content.key?("hidden")
          assert_equal "true", trigger["aria-expanded"]
          assert trigger.key?("data-popup-open"), "open trigger carries bare data-popup-open"
        end

        def test_items_are_role_menuitem_divs_in_the_collection
          html = render_menu
          item = doc(html).css('[data-slot="dropdown-menu-item"]').first

          assert_equal "div", item.name, "menu items are divs, not buttons (APG/Radix-exact)"
          assert_equal "menuitem", item["role"]
          assert_equal "-1", item["tabindex"]
          assert item.key?("data-poetry-collection-item")
          assert_equal "default", item["data-variant"]
          assert_equal "click->poetry--core--menu#activate", item["data-action"]
        end

        def test_item_options_variant_inset_disabled_text_value_close_on_select
          html = render_menu do |menu|
            menu.with_trigger { "Open" }
            menu.with_item(variant: :destructive) { "Delete" }
            menu.with_item(inset: true, text_value: "profile", close_on_select: false) { "Profile" }
            menu.with_item(disabled: true) { "API" }
          end
          destructive, inset, disabled = doc(html).css('[data-slot="dropdown-menu-item"]').to_a

          assert_equal "destructive", destructive["data-variant"]
          assert_equal "true", inset["data-inset"]
          assert_equal "profile", inset["data-text-value"]
          assert_equal "false", inset["data-close-on-select"]
          # divs have no native disabled: aria-disabled + data-disabled together.
          assert_equal "true", disabled["aria-disabled"]
          assert disabled.key?("data-disabled")
        end

        def test_unknown_item_variant_raises
          assert_raises(ArgumentError) do
            render_menu do |menu|
              menu.with_trigger { "Open" }
              menu.with_item(variant: :sparkly) { "Nope" }
            end
          end
        end

        def test_checkbox_item_writes_aria_checked_and_data_checked_together
          html = render_menu do |menu|
            menu.with_trigger { "Open" }
            menu.with_checkbox_item(checked: true, close_on_select: false) { "Status Bar" }
            menu.with_checkbox_item(checked: false) { "Panel" }
          end
          checked, unchecked = doc(html).css('[data-slot="dropdown-menu-checkbox-item"]').to_a

          assert_equal "menuitemcheckbox", checked["role"]
          assert_equal "true", checked["aria-checked"]
          assert checked.key?("data-checked")
          refute checked.key?("data-unchecked")
          assert_equal "false", checked["data-close-on-select"]
          assert_equal "false", unchecked["aria-checked"]
          assert unchecked.key?("data-unchecked")
          refute unchecked.key?("data-checked")

          indicator = checked.css('[data-slot="dropdown-menu-item-indicator"]').first

          assert indicator, "the check indicator ships built in, named (poetry addition over the anonymous span)"
          assert_equal "true", indicator.css("svg").first["aria-hidden"]
        end

        def test_radio_group_scopes_value_and_checks_the_matching_item
          html = render_menu do |menu|
            menu.with_trigger { "Open" }
            menu.with_radio_group(value: "top") do |group|
              group.with_radio_item(value: "top") { "Top" }
              group.with_radio_item(value: "bottom") { "Bottom" }
            end
          end
          group = doc(html).css('[data-slot="dropdown-menu-radio-group"]').first
          top, bottom = group.css('[data-slot="dropdown-menu-radio-item"]').to_a

          assert_equal "group", group["role"]
          assert_equal "top", group["data-value"]
          assert_equal "menuitemradio", top["role"]
          assert_equal(%w[true top], [top["aria-checked"], top["data-value"]])
          assert top.key?("data-checked")
          refute top.key?("data-unchecked")
          assert_equal "false", bottom["aria-checked"]
          assert bottom.key?("data-unchecked")
          refute bottom.key?("data-checked")
          assert_predicate group.css('[data-slot="dropdown-menu-item-indicator"]'), :any?
        end

        def test_duplicate_radio_values_raise
          error = assert_raises(ArgumentError) do
            render_menu do |menu|
              menu.with_trigger { "Open" }
              menu.with_radio_group(value: "top") do |group|
                group.with_radio_item(value: "top") { "Top" }
                group.with_radio_item(value: "top") { "Top again" }
              end
            end
          end

          assert_includes error.message, "duplicate DropdownMenu radio value"
        end

        def test_label_separator_shortcut_and_group_parts
          html = render_menu do |menu|
            menu.with_trigger { "Open" }
            menu.with_label(inset: true) { "My Account" }
            menu.with_group do |group|
              group.with_item(shortcut: "⇧⌘P") { "Profile" }
            end
            menu.with_separator
            menu.with_item { "Billing" }
          end
          fragment = doc(html)
          label = fragment.css('[data-slot="dropdown-menu-label"]').first
          separator = fragment.css('[data-slot="dropdown-menu-separator"]').first
          group = fragment.css('[data-slot="dropdown-menu-group"]').first
          shortcut = fragment.css('[data-slot="dropdown-menu-shortcut"]').first

          assert_equal "My Account", label.text
          assert_equal "true", label["data-inset"]
          assert_nil label["role"], "label is a styled heading, no ARIA role (Radix-exact)"
          assert_equal "separator", separator["role"]
          assert_equal "horizontal", separator["aria-orientation"]
          assert_equal "group", group["role"]
          assert_predicate group.css('[data-slot="dropdown-menu-item"]'), :any?, "groups nest the same item union"
          assert_equal "⇧⌘P", shortcut.text
          assert_equal "true", shortcut["aria-hidden"], "shortcut is a visual hint only (family rule)"
        end

        def test_parts_are_ordered_as_declared
          html = render_menu do |menu|
            menu.with_trigger { "Open" }
            menu.with_label { "Account" }
            menu.with_item { "Profile" }
            menu.with_separator
            menu.with_item(variant: :destructive) { "Delete" }
          end
          slots = doc(html).css('[data-slot="dropdown-menu-content"] > [data-slot]').map { |node| node["data-slot"] }

          assert_equal %w[dropdown-menu-label dropdown-menu-item dropdown-menu-separator dropdown-menu-item], slots
        end

        def test_submenu_renders_a_nested_popper_root_with_its_own_aria_pair
          html = render_menu do |menu|
            menu.with_trigger { "Open" }
            menu.with_sub do |sub|
              sub.with_trigger(inset: true) { "Invite users" }
              sub.with_item { "Email" }
            end
          end
          sub = doc(html).css('[data-slot="dropdown-menu-sub"]').first
          sub_trigger = sub.css('[data-slot="dropdown-menu-sub-trigger"]').first
          sub_content = sub.css('[data-slot="dropdown-menu-sub-content"]').first

          # Each sub is a SECOND popper instance: sub_trigger anchor,
          # sub_content content, side right / align start (LTR).
          assert_equal "poetry--core--popper", sub["data-controller"]
          assert_equal "right", sub["data-poetry--core--popper-side-value"]
          assert_equal "start", sub["data-poetry--core--popper-align-value"]

          assert_equal "menuitem", sub_trigger["role"]
          assert_equal "menu", sub_trigger["aria-haspopup"]
          assert_equal "false", sub_trigger["aria-expanded"]
          assert_equal sub_content["id"], sub_trigger["aria-controls"]
          refute sub_trigger.key?("data-popup-open"), "closed sub-trigger carries NO state attribute"
          assert_equal "true", sub_trigger["data-inset"]
          assert sub_trigger.key?("data-poetry-collection-item"), "sub-trigger sits in the PARENT's collection"
          assert_equal "anchor", sub_trigger["data-poetry--core--popper-target"]
          assert_includes sub_trigger["data-action"], "pointerenter->poetry--core--menu#subEnter"
          assert_includes sub_trigger["data-action"], "pointerleave->poetry--core--menu#subLeave"
          assert_includes sub_trigger["data-action"], "click->poetry--core--menu#openSub"
          assert_predicate sub_trigger.css("svg"), :any?, "the trailing chevron ships built in"

          assert_equal "menu", sub_content["role"]
          assert_equal sub_trigger["id"], sub_content["aria-labelledby"]
          assert sub_content.key?("data-closed"), "mounted-closed sub popup carries bare data-closed"
          assert sub_content.key?("hidden")
          assert_equal "content", sub_content["data-poetry--core--popper-target"]
          assert_nil sub_content["data-controller"], "sub layer controllers are runtime-activated"
        end

        def test_rtl_flips_the_submenu_side_and_sets_dir
          html = render_menu(dir: :rtl) do |menu|
            menu.with_trigger { "Open" }
            menu.with_sub do |sub|
              sub.with_trigger { "More" }
              sub.with_item { "Import" }
            end
          end
          root = doc(html).css('[data-slot="dropdown-menu"]').first
          sub = doc(html).css('[data-slot="dropdown-menu-sub"]').first

          assert_equal "rtl", root["dir"]
          assert_equal "left", sub["data-poetry--core--popper-side-value"]
        end

        def test_required_slot_guards
          assert_raises(ArgumentError, "missing trigger") do
            render_inline(Component.new) { |menu| menu.with_item { "Profile" } }
          end
          assert_raises(ArgumentError, "missing items") do
            render_inline(Component.new) { |menu| menu.with_trigger { "Open" } }
          end
          assert_raises(ArgumentError, "sub missing trigger") do
            render_inline(Component.new) do |menu|
              menu.with_trigger { "Open" }
              menu.with_sub { |sub| sub.with_item { "Email" } }
            end
          end
          assert_raises(ArgumentError, "empty radio group") do
            render_inline(Component.new) do |menu|
              menu.with_trigger { "Open" }
              menu.with_radio_group(value: "x")
            end
          end
        end

        def test_disabled_menu_disables_the_composed_trigger_button
          html = render_menu(disabled: true)
          trigger = doc(html).css('button[data-slot="dropdown-menu-trigger"]').first

          assert trigger.key?("disabled")
        end

        def test_source_exact_classes_land_on_content_and_item
          html = render_menu

          assert_includes html, "max-h-(--radix-dropdown-menu-content-available-height)"
          assert_includes html, "origin-(--radix-dropdown-menu-content-transform-origin)"
          assert_includes html, "data-[variant=destructive]:focus:bg-destructive/10"
        end
      end
    end
  end
end
