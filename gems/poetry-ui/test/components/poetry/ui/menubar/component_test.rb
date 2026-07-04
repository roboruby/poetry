# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Menubar
      class ComponentTest < ViewComponent::TestCase
        # The class strings carry ">" ([&_svg...] selectors) - attribute
        # assertions go through Nokogiri, never [^>]* regexes across
        # class attributes (the Accordion test hazard).
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def render_bar(**options, &block)
          options[:label] = "Application menu" unless options.key?(:label)
          block ||= lambda { |bar|
            bar.with_menu do |menu|
              menu.with_trigger { "File" }
              menu.with_item { "New Tab" }
              menu.with_item { "New Window" }
            end
            bar.with_menu do |menu|
              menu.with_trigger { "Edit" }
              menu.with_item { "Undo" }
            end
          }
          render_inline(Component.new(**options), &block).to_html
        end

        def test_bar_is_a_labelled_menubar_hosting_coordinator_and_horizontal_roving
          html = render_bar
          bar = doc(html).css('[data-slot="menubar"]').first

          assert_equal "menubar", bar["data-component"]
          assert_equal "menubar", bar["role"]
          assert_equal "Application menu", bar["aria-label"]
          # The bar ROOT keeps the mounted open/closed pair (W1 resolution).
          assert bar.key?("data-closed")
          refute bar.key?("data-open")
          # ONE shared Attributes instance: token-concatenated, not overwritten.
          assert_equal "poetry--core--menubar poetry--core--roving-focus", bar["data-controller"]
          assert_equal "", bar["data-poetry--core--menubar-value-value"]
          assert_equal "false", bar["data-poetry--core--menubar-loop-value"]
          # The bar DELTA: horizontal roving, manageTabindex TRUE (one tab stop).
          assert_equal "horizontal", bar["data-poetry--core--roving-focus-orientation-value"]
          assert_equal "true", bar["data-poetry--core--roving-focus-manage-tabindex-value"]
          assert_equal "false", bar["data-poetry--core--roving-focus-loop-value"]
          assert_includes bar["data-action"], "keydown->poetry--core--roving-focus#keydown"
          # The coordinator's two event seams.
          assert_includes bar["data-action"], "poetry:menu:edge-navigate->poetry--core--menubar#slideAdjacent"
          assert_includes bar["data-action"], "poetry:menu:closed->poetry--core--menubar#onMenuClosed"
        end

        def test_label_is_required
          error = assert_raises(ArgumentError) { render_bar(label: nil) }

          assert_includes error.message, "label"
        end

        def test_at_least_one_menu_is_required
          assert_raises(ArgumentError) { render_inline(Component.new(label: "Menu")) }
        end

        def test_menu_wrapper_hosts_the_per_menu_machinery_out_of_layout
          html = render_bar
          wrapper = doc(html).css('[data-slot="menubar-menu"]').first

          # display:contents - the controller scope stays out of the bar's
          # flex layout and the accessibility tree (Radix renders no element).
          assert_includes wrapper["class"], "contents"
          assert_equal "poetry--core--menu poetry--core--popper", wrapper["data-controller"]
          assert_equal "false", wrapper["data-poetry--core--menu-open-value"]
          # modal FALSE: hover-slide needs sibling triggers pressable.
          assert_equal "false", wrapper["data-poetry--core--menu-modal-value"]
          # The menubar positioning overrides (source-validated): align
          # start / alignOffset -4 / sideOffset 8.
          assert_equal "bottom", wrapper["data-poetry--core--popper-side-value"]
          assert_equal "start", wrapper["data-poetry--core--popper-align-value"]
          assert_equal "8", wrapper["data-poetry--core--popper-side-offset-value"]
          assert_equal "-4", wrapper["data-poetry--core--popper-align-offset-value"]
        end

        def test_triggers_are_menuitem_buttons_with_exactly_one_tab_stop
          html = render_bar
          triggers = doc(html).css('button[data-slot="menubar-trigger"]')

          assert_equal 2, triggers.size
          triggers.each do |trigger|
            assert_equal "button", trigger["type"]
            # The trigger ARIA delta: role=menuitem INSIDE role=menubar.
            assert_equal "menuitem", trigger["role"]
            assert_equal "menu", trigger["aria-haspopup"]
            assert_equal "false", trigger["aria-expanded"]
            refute trigger.key?("data-popup-open"), "closed trigger carries NO state attribute (absence IS the state)"
            assert trigger.key?("data-poetry-collection-item")
            assert_equal "anchor", trigger["data-poetry--core--popper-target"]
            assert_includes trigger["data-action"], "pointerdown->poetry--core--menubar#toggle"
            assert_includes trigger["data-action"], "pointerenter->poetry--core--menubar#hoverSlide"
            assert_includes trigger["data-action"], "keydown->poetry--core--menubar#triggerKeydown"
          end
          # Exactly one tabindex=0 in the bar, server-rendered (no-JS truth).
          stops = triggers.map { |trigger| trigger["tabindex"] }

          assert_equal %w[0 -1], stops
        end

        def test_aria_pairs_wire_trigger_and_content_both_ways
          html = render_bar
          doc(html).css('[data-slot="menubar-menu"]').each do |wrapper|
            trigger = wrapper.css('[data-slot="menubar-trigger"]').first
            content = wrapper.css('[data-slot="menubar-content"]').first

            assert_equal content["id"], trigger["aria-controls"]
            assert_equal trigger["id"], content["aria-labelledby"]
          end
        end

        def test_content_is_a_closed_menu_with_no_static_layer_controllers
          html = render_bar
          content = doc(html).css('[data-slot="menubar-content"]').first

          assert_equal "menu", content["role"]
          assert_equal "vertical", content["aria-orientation"]
          assert_equal "-1", content["tabindex"]
          assert content.key?("data-closed"), "mounted-closed popup carries bare data-closed"
          refute content.key?("data-open")
          assert content.key?("hidden"), "closed content is hidden (truthful server render)"
          assert_equal "bottom", content["data-side"]
          assert_equal "start", content["data-align"]
          assert_equal "content", content["data-poetry--core--popper-target"]
          # The layer controllers are token-ACTIVATED by the menu controller on open.
          assert_nil content["data-controller"]
        end

        def test_value_server_renders_the_open_menu_and_moves_the_tab_stop
          html = render_bar(value: "file") do |bar|
            bar.with_menu(value: "file") do |menu|
              menu.with_trigger { "File" }
              menu.with_item { "New Tab" }
            end
            bar.with_menu(value: "edit") do |menu|
              menu.with_trigger { "Edit" }
              menu.with_item { "Undo" }
            end
          end
          bar = doc(html).css('[data-slot="menubar"]').first
          file, edit = doc(html).css('[data-slot="menubar-trigger"]').to_a
          file_content = doc(html).css('[data-slot="menubar-content"]').first

          assert bar.key?("data-open")
          refute bar.key?("data-closed")
          assert_equal "file", bar["data-poetry--core--menubar-value-value"]
          assert file.key?("data-popup-open"), "open trigger carries bare data-popup-open"
          assert_equal(%w[true 0 file], [file["aria-expanded"], file["tabindex"], file["data-value"]])
          refute edit.key?("data-popup-open"), "closed trigger carries NO state attribute"
          assert_equal(%w[false -1], [edit["aria-expanded"], edit["tabindex"]])
          assert file_content.key?("data-open"), "open popup carries bare data-open"
          refute file_content.key?("data-closed")
          refute file_content.key?("hidden")
        end

        def test_menu_values_default_to_positional_and_disabled_menus_lose_the_tab_stop
          html = render_bar do |bar|
            bar.with_menu(disabled: true) do |menu|
              menu.with_trigger { "File" }
              menu.with_item { "New" }
            end
            bar.with_menu do |menu|
              menu.with_trigger { "Edit" }
              menu.with_item { "Undo" }
            end
          end
          file, edit = doc(html).css('[data-slot="menubar-trigger"]').to_a

          assert_equal "menu-1", file["data-value"]
          assert_equal "menu-2", edit["data-value"]
          assert file.key?("disabled")
          assert file.key?("data-disabled")
          # The tab stop skips the disabled leading menu.
          assert_equal(%w[-1 0], [file["tabindex"], edit["tabindex"]])
        end

        def test_menu_requires_trigger_and_items
          assert_raises(ArgumentError, "missing trigger") do
            render_inline(Component.new(label: "Menu")) do |bar|
              bar.with_menu { |menu| menu.with_item { "New" } }
            end
          end
          assert_raises(ArgumentError, "missing items") do
            render_inline(Component.new(label: "Menu")) do |bar|
              bar.with_menu { |menu| menu.with_trigger { "File" } }
            end
          end
        end

        def test_the_family_item_union_renders_with_menubar_slots
          html = render_bar do |bar|
            bar.with_menu do |menu|
              menu.with_trigger { "View" }
              menu.with_label(inset: true) { "Appearance" }
              menu.with_checkbox_item(checked: true, close_on_select: false, shortcut: "⌘B") { "Bookmarks" }
              menu.with_separator
              menu.with_radio_group(value: "benoit") do |group|
                group.with_radio_item(value: "andy") { "Andy" }
                group.with_radio_item(value: "benoit") { "Benoit" }
              end
              menu.with_group do |group|
                group.with_item(variant: :destructive) { "Reset" }
              end
            end
          end
          fragment = doc(html)
          label = fragment.css('[data-slot="menubar-label"]').first
          checkbox = fragment.css('[data-slot="menubar-checkbox-item"]').first
          separator = fragment.css('[data-slot="menubar-separator"]').first
          radio_group = fragment.css('[data-slot="menubar-radio-group"]').first
          andy, benoit = radio_group.css('[data-slot="menubar-radio-item"]').to_a
          group = fragment.css('[data-slot="menubar-group"]').first
          shortcut = fragment.css('[data-slot="menubar-shortcut"]').first

          assert_equal "true", label["data-inset"]
          assert_equal "menuitemcheckbox", checkbox["role"]
          assert_equal "true", checkbox["aria-checked"]
          assert checkbox.key?("data-checked")
          refute checkbox.key?("data-unchecked")
          assert_equal "separator", separator["role"]
          assert_equal "benoit", radio_group["data-value"]
          assert_equal "false", andy["aria-checked"]
          assert andy.key?("data-unchecked")
          refute andy.key?("data-checked")
          assert_equal "true", benoit["aria-checked"]
          assert benoit.key?("data-checked")
          refute benoit.key?("data-unchecked")
          assert_equal "group", group["role"]
          assert_equal "destructive", group.css('[data-slot="menubar-item"]').first["data-variant"]
          assert_equal "⌘B", shortcut.text
          assert_equal "true", shortcut["aria-hidden"], "shortcut is a visual hint only (family rule)"
        end

        def test_duplicate_radio_values_raise
          error = assert_raises(ArgumentError) do
            render_bar do |bar|
              bar.with_menu do |menu|
                menu.with_trigger { "Profiles" }
                menu.with_radio_group(value: "a") do |group|
                  group.with_radio_item(value: "a") { "A" }
                  group.with_radio_item(value: "a") { "A again" }
                end
              end
            end
          end

          assert_includes error.message, "duplicate Menubar radio value"
        end

        def test_submenu_renders_a_nested_popper_root_with_its_own_aria_pair
          html = render_bar do |bar|
            bar.with_menu do |menu|
              menu.with_trigger { "File" }
              menu.with_sub do |sub|
                sub.with_trigger { "Share" }
                sub.with_item { "Email link" }
              end
            end
          end
          sub = doc(html).css('[data-slot="menubar-sub"]').first
          sub_trigger = sub.css('[data-slot="menubar-sub-trigger"]').first
          sub_content = sub.css('[data-slot="menubar-sub-content"]').first

          assert_equal "poetry--core--popper", sub["data-controller"]
          assert_equal "right", sub["data-poetry--core--popper-side-value"]
          assert_equal "start", sub["data-poetry--core--popper-align-value"]
          assert_equal "menuitem", sub_trigger["role"]
          assert_equal "menu", sub_trigger["aria-haspopup"]
          assert_equal sub_content["id"], sub_trigger["aria-controls"]
          assert_predicate sub_trigger.css("svg"), :any?, "the trailing chevron ships built in"
          assert_equal "menu", sub_content["role"]
          assert_equal sub_trigger["id"], sub_content["aria-labelledby"]
          assert sub_content.key?("hidden")
          assert_nil sub_content["data-controller"], "sub layer controllers are runtime-activated"
        end

        def test_rtl_flips_the_submenu_side_and_sets_dir
          html = render_bar(dir: :rtl) do |bar|
            bar.with_menu do |menu|
              menu.with_trigger { "ملف" }
              menu.with_sub do |sub|
                sub.with_trigger { "مشاركة" }
                sub.with_item { "بريد" }
              end
            end
          end
          bar = doc(html).css('[data-slot="menubar"]').first
          sub = doc(html).css('[data-slot="menubar-sub"]').first

          assert_equal "rtl", bar["dir"]
          assert_equal "left", sub["data-poetry--core--popper-side-value"]
        end

        def test_source_exact_classes_land_per_part
          html = render_bar do |bar|
            bar.with_menu do |menu|
              menu.with_trigger { "View" }
              menu.with_checkbox_item(close_on_select: false) { "Bookmarks" }
              menu.with_sub do |sub|
                sub.with_trigger { "Share" }
                sub.with_item { "Email" }
              end
            end
          end
          fragment = doc(html)
          bar = fragment.css('[data-slot="menubar"]').first
          content = fragment.css('[data-slot="menubar-content"]').first
          checkbox = fragment.css('[data-slot="menubar-checkbox-item"]').first
          sub_trigger = fragment.css('[data-slot="menubar-sub-trigger"]').first

          %w[flex h-9 items-center gap-1 rounded-md border bg-background p-1 shadow-xs].each do |token|
            assert_includes bar["class"].split, token
          end
          assert_includes content["class"], "min-w-[12rem]"
          assert_includes content["class"], "origin-(--radix-menubar-content-transform-origin)"
          # The source's own quirks, kept verbatim:
          refute_includes content["class"], "data-closed:animate-out"
          assert_includes checkbox["class"], "rounded-xs"
          assert_includes sub_trigger["class"].split, "outline-none"
        end
      end
    end
  end
end
