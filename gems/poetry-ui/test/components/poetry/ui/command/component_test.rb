# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Command
      class ComponentTest < ViewComponent::TestCase
        # The class strings carry ">" ([&_svg...] selectors) - attribute
        # assertions go through Nokogiri, never regexes across class
        # attributes (the Accordion test hazard).
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def render_command(**, &block)
          block ||= lambda { |command|
            command.with_group(heading: "Suggestions") do |group|
              group.with_item(value: "calendar", keywords: %w[schedule dates]) { "Calendar" }
              group.with_item(value: "emoji") { "Search Emoji" }
              group.with_item(value: "calculator", disabled: true) { "Calculator" }
            end
            command.with_separator
            command.with_group(heading: "Settings") do |group|
              group.with_item(value: "profile", shortcut: "⌘P") { "Profile" }
            end
          }
          defaults = { "aria-label": "Command palette" }
          render_inline(Component.new(**defaults, **), &block).to_html
        end

        ALL_SLOTS = %w[command command-input-wrapper command-search-icon command-input command-list
                       command-empty command-loading command-group command-group-heading command-item
                       command-item-text command-shortcut command-separator command-status].freeze

        def test_all_fourteen_data_slots_render
          fragment = doc(render_command)

          ALL_SLOTS.each do |slot|
            assert_predicate fragment.css(%([data-slot="#{slot}"])), :any?, "missing data-slot #{slot}"
          end
        end

        def test_root_hosts_the_command_controller_with_its_values
          root = doc(render_command).css('[data-slot="command"]').first

          assert_equal "command", root["data-component"]
          assert_equal "poetry--core--command", root["data-controller"]
          assert_equal "true", root["data-poetry--core--command-filter-value"]
          assert_equal "false", root["data-poetry--core--command-loop-value"]
          # The popover chrome rides .cn-command; the layout stays inline.
          %w[cn-command flex h-full w-full flex-col
             overflow-hidden].each { |token| assert_includes root["class"], token }
        end

        def test_filter_false_renders_the_server_driven_mode
          root = doc(render_command(filter: false)).css('[data-slot="command"]').first

          assert_equal "false", root["data-poetry--core--command-filter-value"]
        end

        def test_input_is_the_aria_wired_combobox
          fragment = doc(render_command(placeholder: "Type a command..."))
          input = fragment.css('input[data-slot="command-input"]').first
          list = fragment.css('[data-slot="command-list"]').first

          assert_equal "text", input["type"]
          assert_equal "combobox", input["role"]
          assert_equal "true", input["aria-expanded"], "the listbox is always visible - statically true"
          assert_equal list["id"], input["aria-controls"]
          assert_equal "list", input["aria-autocomplete"]
          assert_equal "off", input["autocomplete"]
          assert_equal "off", input["autocorrect"]
          assert_equal "false", input["spellcheck"]
          assert_equal "Type a command...", input["placeholder"]
          assert_equal "Command palette", input["aria-label"]
          assert_includes input["data-action"], "input->poetry--core--command#filterInput"
          assert_includes input["data-action"], "keydown->poetry--core--command#keydown"
          # The h-10-inside-h-9 clip is load-bearing and now lives in the
          # theme pair (.cn-command-input / .cn-command-input-wrapper).
          assert_includes input["class"], "cn-command-input"
          assert_includes input["class"], "outline-hidden"
          wrapper = fragment.css('[data-slot="command-input-wrapper"]').first

          assert_includes wrapper["class"], "cn-command-input-wrapper"
          icon = fragment.css('[data-slot="command-search-icon"] svg').first

          assert_equal "true", icon["aria-hidden"], "the magnifier is decorative"
        end

        def test_input_aria_lands_on_the_input_never_the_root
          fragment = doc(render_command)
          root = fragment.css('[data-slot="command"]').first

          assert_nil root["aria-label"]
        end

        def test_list_is_a_labelled_listbox
          list = doc(render_command).css('[data-slot="command-list"]').first

          assert_equal "listbox", list["role"]
          assert_equal "-1", list["tabindex"]
          assert_equal "Commands", list["aria-label"], "t('poetry.command.list_label') default"
          assert_includes list["class"], "cn-command-list"
        end

        def test_list_label_overrides_the_listbox_name
          list = doc(render_command(list_label: "Jump to")).css('[data-slot="command-list"]').first

          assert_equal "Jump to", list["aria-label"]
        end

        def test_items_carry_unique_server_ids_and_data_value_and_never_tabindex_or_aria_selected
          fragment = doc(render_command)
          items = fragment.css('[data-slot="command-item"]')

          assert_equal 4, items.size
          ids = items.map { |item| item["id"] }

          assert_equal ids.uniq, ids
          root_id = fragment.css('[data-slot="command"]').first["id"]

          assert_equal((0..3).map { |index| "#{root_id}-item-#{index}" }, ids,
                       "server-stable ids in render order - the activedescendant contract")
          assert_equal(%w[calendar emoji calculator profile], items.map { |item| item["data-value"] })
          items.each do |item|
            assert_equal "option", item["role"]
            assert item.key?("data-poetry-collection-item")
            assert_nil item["tabindex"], "options are NEVER focused (activedescendant, not roving focus)"
            assert_nil item["aria-selected"], "aria-selected is reserved for committed values (Combobox)"
            assert_includes item["data-action"], "click->poetry--core--command#activate"
            assert_includes item["data-action"], "pointermove->poetry--core--command#pointerHighlight"
          end
        end

        def test_item_classes_carry_the_data_highlighted_delta
          item = doc(render_command).css('[data-slot="command-item"]').first

          # The data-[highlighted] delta rides .cn-command-item in the theme.
          assert_includes item["class"], "cn-command-item"
          assert_includes item["class"], "data-[disabled]:pointer-events-none"
          refute_includes item["class"], "data-[selected=true]", "the one deliberate class delta vs source"
        end

        def test_item_extras_land_as_data_attributes
          html = render_command do |command|
            command.with_item(value: "calendar", keywords: %w[schedule dates],
                              filter_value: "Calendar", always_render: true) { "📅 Calendar" }
          end
          item = doc(html).css('[data-slot="command-item"]').first

          assert_equal "schedule dates", item["data-keywords"]
          assert_equal "Calendar", item["data-filter-value"]
          assert item.key?("data-always-render")
        end

        def test_disabled_items_wear_the_aria_data_twins
          disabled = doc(render_command).css('[data-slot="command-item"][data-value="calculator"]').first

          assert_equal "true", disabled["aria-disabled"]
          assert disabled.key?("data-disabled")
        end

        def test_shortcut_renders_ms_auto_and_item_text_excludes_it
          item = doc(render_command).css('[data-slot="command-item"][data-value="profile"]').first
          shortcut = item.css('[data-slot="command-shortcut"]').first

          assert_equal "⌘P", shortcut.text
          # The RTL logical fix (ms-auto over source's ml-auto) rides the theme.
          assert_includes shortcut["class"], "cn-command-shortcut"
          assert_equal "Profile", item.css('[data-slot="command-item-text"]').first.text,
                       "the shortcut lives OUTSIDE the filterable label"
        end

        def test_groups_are_labelled_by_their_heading_ids
          fragment = doc(render_command)
          group = fragment.css('[data-slot="command-group"]').first
          heading = group.css('[data-slot="command-group-heading"]').first

          assert_equal "group", group["role"]
          assert_equal heading["id"], group["aria-labelledby"]
          assert_equal "Suggestions", heading.text
          assert_nil heading["role"], "the heading is labelling text, no ARIA role"
          assert_includes group["class"], "overflow-hidden"
          assert_includes heading["class"], "cn-command-group-heading"
        end

        def test_separator_is_visible_but_decorative
          separator = doc(render_command).css('[data-slot="command-separator"]').first

          # Inside role=listbox only option/group children are valid (axe
          # aria-required-children) - decorative separator, no role.
          assert_equal "true", separator["aria-hidden"]
          assert_nil separator["role"]
          refute separator.key?("hidden"), "server renders separators visible; the controller hides on query"
          assert_includes separator["class"], "cn-command-separator"
        end

        def test_empty_and_loading_render_hidden_and_status_renders_sr_only
          fragment = doc(render_command)
          empty = fragment.css('[data-slot="command-empty"]').first
          loading = fragment.css('[data-slot="command-loading"]').first
          status = fragment.css('[data-slot="command-status"]').first

          assert empty.key?("hidden")
          assert_equal "No results found.", empty.text
          assert loading.key?("hidden")
          assert_equal "status", loading["role"]
          assert_equal "Loading…", loading.text.strip
          refute status.key?("hidden"), "the live region must stay in the tree - sr-only, not hidden"
          assert_equal "status", status["role"]
          assert_equal "polite", status["aria-live"]
          assert_includes status["class"], "sr-only"
        end

        def test_status_carries_the_localized_count_templates
          status = doc(render_command).css('[data-slot="command-status"]').first

          assert_equal "0 results", status["data-zero"]
          assert_equal "1 result", status["data-one"]
          assert_equal "%{count} results", status["data-other"], # rubocop:disable Style/FormatStringToken
                       "a LITERAL placeholder for the controller"
        end

        def test_custom_empty_and_loading_slot_content
          html = render_command do |command|
            command.with_empty { "Nothing here." }
            command.with_loading { "Fetching…" }
            command.with_item(value: "a") { "A" }
          end
          fragment = doc(html)

          assert_equal "Nothing here.", fragment.css('[data-slot="command-empty"]').first.text
          assert_includes fragment.css('[data-slot="command-loading"]').first.text, "Fetching…"
        end

        def test_initial_highlight_seats_on_the_first_enabled_item
          html = render_command do |command|
            command.with_item(value: "cut", disabled: true) { "Cut" }
            command.with_item(value: "copy") { "Copy" }
            command.with_item(value: "paste") { "Paste" }
          end
          fragment = doc(html)
          highlighted = fragment.css("[data-highlighted]")
          input = fragment.css('[data-slot="command-input"]').first

          assert_equal 1, highlighted.size, "exactly one data-highlighted"
          assert_equal "copy", highlighted.first["data-value"], "disabled items never take the seat"
          assert_equal highlighted.first["id"], input["aria-activedescendant"],
                       "the twin-write: data-highlighted + activedescendant together"
        end

        def test_value_option_seats_the_initial_highlight
          html = render_command(value: "emoji")
          fragment = doc(html)
          highlighted = fragment.css("[data-highlighted]")

          assert_equal(["emoji"], highlighted.map { |item| item["data-value"] })
          assert_equal highlighted.first["id"],
                       fragment.css('[data-slot="command-input"]').first["aria-activedescendant"]
        end

        def test_unknown_value_leaves_the_highlight_to_the_controller
          fragment = doc(render_command(value: "nope"))

          assert_empty fragment.css("[data-highlighted]")
          assert_nil fragment.css('[data-slot="command-input"]').first["aria-activedescendant"]
        end

        def test_duplicate_item_values_raise
          error = assert_raises(ArgumentError) do
            render_command do |command|
              command.with_item(value: "calendar") { "Calendar" }
              command.with_group(heading: "More") { |group| group.with_item(value: "calendar") { "Again" } }
            end
          end

          assert_includes error.message, "duplicate Command item value"
        end

        def test_blank_item_value_raises
          assert_raises(ArgumentError) do
            render_command { |command| command.with_item(value: "") { "Empty" } }
          end
        end

        def test_group_requires_a_heading_and_items
          assert_raises(ArgumentError, "blank heading") do
            render_command { |command| command.with_group(heading: "") { |group| group.with_item(value: "a") { "A" } } }
          end
          assert_raises(ArgumentError, "empty group") do
            render_command { |command| command.with_group(heading: "G") }
          end
        end

        def test_a_nameless_bare_command_fails_the_render
          error = assert_raises(ArgumentError) do
            render_inline(Component.new) { |command| command.with_item(value: "a") { "A" } }
          end

          assert_includes error.message, "accessible name"
        end

        def test_an_explicit_id_derives_input_list_and_item_ids
          fragment = doc(render_command(id: "palette"))

          assert_equal "palette", fragment.css('[data-slot="command"]').first["id"]
          assert_equal "palette-input", fragment.css('[data-slot="command-input"]').first["id"]
          assert_equal "palette-list", fragment.css('[data-slot="command-list"]').first["id"]
          assert_equal "palette-item-0", fragment.css('[data-slot="command-item"]').first["id"]
        end

        def test_disabled_disables_the_input
          input = doc(render_command(disabled: true)).css('[data-slot="command-input"]').first

          assert input.key?("disabled")
        end

        def test_parts_are_ordered_as_declared_with_empty_and_loading_first
          html = render_command do |command|
            command.with_item(value: "a") { "A" }
            command.with_separator
            command.with_group(heading: "G") { |group| group.with_item(value: "b") { "B" } }
          end
          slots = doc(html).css('[data-slot="command-list"] > [data-slot]').map { |node| node["data-slot"] }

          assert_equal %w[command-empty command-loading command-item command-separator command-group], slots
        end

        # -- the CommandDialog variant ------------------------------------------

        def render_dialog(**, &block)
          block ||= lambda { |palette|
            palette.with_trigger(variant: :outline) { "Open" }
            palette.with_group(heading: "Suggestions") do |group|
              group.with_item(value: "calendar") { "Calendar" }
              group.with_item(value: "profile", shortcut: "⌘P") { "Profile" }
            end
          }
          render_inline(DialogComponent.new(**), &block).to_html
        end

        def test_dialog_variant_renders_the_sr_only_labelled_dialog
          fragment = doc(render_dialog)
          root = fragment.css('[data-slot="command-dialog"]').first
          dialog = fragment.css('dialog[data-slot="dialog-content"]').first
          header = fragment.css('[data-slot="dialog-header"]').first
          title = fragment.css('[data-slot="dialog-title"]').first
          description = fragment.css('[data-slot="dialog-description"]').first

          assert_equal "command-dialog", root["data-component"]
          assert_equal "poetry--core--dialog", root["data-controller"]
          assert_includes header["class"], "sr-only"
          assert_equal "Command palette", title.text, "t('poetry.command.dialog_title') source default"
          assert_equal "Search for a command to run…", description.text
          assert_equal title["id"], dialog["aria-labelledby"]
          assert_equal description["id"], dialog["aria-describedby"]
          # The source's structural pair rides inline (utilities beat every
          # theme's cn-dialog-content padding); the hook carries the
          # themes' radius retunes.
          assert_includes dialog["class"], "cn-command-dialog"
          assert_includes dialog["class"], "overflow-hidden"
          assert_includes dialog["class"], "p-0"
          refute_includes dialog["class"], "p-6"
        end

        def test_dialog_variant_leaves_the_palette_sizing_to_the_theme
          command_root = doc(render_dialog).css('[data-slot="command"]').first

          # The classic h-12 chain rides the default theme's .cn-command-dialog
          # rule (see the theme rules test); the styled sources carry none,
          # so nothing inline may impose it on the ported themes.
          refute_match(/h-12|py-3/, command_root["class"])
          assert_includes command_root["class"], "cn-command"
        end

        def test_dialog_variant_labels_the_input_with_the_i18n_fallback
          input = doc(render_dialog).css('[data-slot="command-input"]').first

          assert_equal "Search commands", input["aria-label"], "t('poetry.command.input_label')"
        end

        def test_dialog_variant_hotkey_is_opt_in
          root = doc(render_dialog).css('[data-slot="command-dialog"]').first

          assert_nil root["data-poetry--core--dialog-hotkey-value"]

          wired = doc(render_dialog(hotkey: "meta+k")).css('[data-slot="command-dialog"]').first

          assert_equal "meta+k", wired["data-poetry--core--dialog-hotkey-value"]
        end

        CLOSE_X = 'dialog [data-component="button"][aria-label="Close"]'

        def test_dialog_variant_trigger_wires_open
          trigger = doc(render_dialog).css('[data-component="button"]').first

          assert_includes trigger["data-action"], "poetry--core--dialog#open"
        end

        def test_dialog_variant_close_button_defaults_to_the_inverse_of_dismissible
          assert_empty doc(render_dialog).css(CLOSE_X),
                       "keyboard-first: no X while the backdrop closes the palette (the styled source's default)"
          assert_predicate doc(render_dialog(dismissible: false)).css(CLOSE_X), :any?, "a pointer needs a way out"
          assert_predicate doc(render_dialog(show_close_button: true)).css(CLOSE_X), :any?
          assert_empty doc(render_dialog(dismissible: false, show_close_button: false)).css(CLOSE_X),
                       "an explicit false wins over the derived default"
        end

        def test_dialog_variant_close_button_seats_in_the_input_row
          fragment = doc(render_dialog(show_close_button: true))
          wrapper = fragment.css('[data-slot="command-input-wrapper"]').first
          close = wrapper.css('[data-component="button"][aria-label="Close"]').first

          refute_nil close, "the X is the input row's trailing item, never laid over the input"
          assert_equal "command-input", close.previous_element["data-slot"]
          assert_includes close["class"], "cn-dialog-close"
          assert_includes close["class"], "static", "beats the themed absolute offset"
          assert_includes close["class"], "shrink-0"
          refute_includes close["class"], "top-2"
          assert_includes close["data-action"], "poetry--core--dialog#close"
          assert_equal 1, fragment.css(CLOSE_X).size, "one X, in the row - none over the panel"
        end
      end
    end
  end
end
