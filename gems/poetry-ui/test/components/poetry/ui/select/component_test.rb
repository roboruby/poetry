# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Select
      class ComponentTest < ViewComponent::TestCase
        # The class strings carry ">" ([&_svg...] selectors) - attribute
        # assertions go through Nokogiri, never [^>]* regexes across
        # class attributes (the Accordion test hazard).
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def render_select(**, &block)
          block ||= lambda { |select|
            select.with_item(value: "apple") { "Apple" }
            select.with_item(value: "banana") { "Banana" }
          }
          defaults = { "aria-label": "Fruit", placeholder: "Select a fruit" }
          render_inline(Component.new(**defaults, **), &block).to_html
        end

        def test_root_hosts_both_controllers_on_one_attributes_instance
          html = render_select
          root = doc(html).css('[data-slot="select"]').first

          assert_equal "select", root["data-component"]
          # ONE shared Attributes instance: token-concatenated, not overwritten.
          assert_equal "poetry--core--select poetry--core--popper", root["data-controller"]
          assert_equal "false", root["data-poetry--core--select-open-value"]
          assert_equal "", root["data-poetry--core--select-value-value"]
          assert_equal "true", root["data-poetry--core--select-modal-value"]
          assert_equal "false", root["data-poetry--core--select-loop-value"]
          assert_equal "bottom", root["data-poetry--core--popper-side-value"]
          assert_equal "start", root["data-poetry--core--popper-align-value"]
          assert_equal "4", root["data-poetry--core--popper-side-offset-value"]
          assert_equal "true", root["data-poetry--core--popper-avoid-collisions-value"]
        end

        def test_trigger_is_an_aria_wired_combobox_button
          html = render_select
          trigger = doc(html).css('button[data-slot="select-trigger"]').first
          content = doc(html).css('[data-slot="select-content"]').first

          assert_equal "combobox", trigger["role"]
          assert_equal "button", trigger["type"], "never an implicit submit"
          assert_equal "false", trigger["aria-expanded"]
          assert_equal content["id"], trigger["aria-controls"]
          assert_equal "none", trigger["aria-autocomplete"]
          refute trigger.key?("data-popup-open"), "closed trigger carries NO state attribute (absence IS the state)"
          assert_equal "default", trigger["data-size"]
          assert_equal "Fruit", trigger["aria-label"]
          assert_equal "anchor", trigger["data-poetry--core--popper-target"]
          assert_includes trigger["data-action"], "click->poetry--core--select#toggle"
          assert_includes trigger["data-action"], "keydown->poetry--core--select#triggerKeydown"
          assert trigger.key?("data-placeholder"), "empty value dims the display (data-[placeholder])"
          assert_predicate trigger.css("svg"), :any?, "the trailing chevron ships built in"
        end

        def test_value_display_shows_the_placeholder_then_the_selected_label
          placeholder_value = doc(render_select).css('[data-slot="select-value"]').first

          assert_equal "Select a fruit", placeholder_value.text
          assert_equal "Select a fruit", placeholder_value["data-placeholder"],
                       "the span carries the placeholder so a clear can restore it"

          html = render_select(value: "banana")
          fragment = doc(html)
          display = fragment.css('[data-slot="select-value"]').first

          assert_equal "Banana", display.text, "the LABEL, never the raw value"
          refute fragment.css('[data-slot="select-trigger"]').first.key?("data-placeholder")
        end

        def test_native_select_is_the_server_rendered_serialization_truth
          html = render_select(name: "cart[fruit]", value: "banana", required: true)
          native = doc(html).css('select[data-slot="select-native"]').first
          options = native.css("option")

          assert_equal "cart[fruit]", native["name"]
          assert_equal "true", native["aria-hidden"]
          assert_equal "-1", native["tabindex"]
          assert native.key?("required"), "native constraint validation rides the real select"
          assert_includes native["class"], "sr-only", "visually hidden, never display:none (autofill needs paint)"
          assert_equal "change->poetry--core--select#nativeChanged", native["data-action"]
          # The blank option rides the placeholder; the value's option is selected.
          assert_equal(["", "apple", "banana"], options.map { |option| option["value"] })
          assert_equal "Select a fruit", options.first.text
          assert options.find { |option| option["value"] == "banana" }.key?("selected")
          refute options.first.key?("selected")
        end

        def test_native_blank_option_is_selected_when_no_value
          native = doc(render_select).css('[data-slot="select-native"]').first
          options = native.css("option")

          assert options.first.key?("selected"), "the blank option holds the empty value pre-commit"
          assert(options[1..].none? { |option| option.key?("selected") })
        end

        def test_content_is_a_closed_labelled_listbox_with_no_static_layer_controllers
          html = render_select
          content = doc(html).css('[data-slot="select-content"]').first
          trigger = doc(html).css('[data-slot="select-trigger"]').first

          # role=listbox lives on the VIEWPORT (options' parent) - the popup
          # shell holds scroll buttons too (axe aria-required-children,
          # 2026-07-03).
          viewport = doc(html).css('[data-slot="select-viewport"]').first

          assert_nil content["role"]
          assert_equal "listbox", viewport["role"]
          assert_equal trigger["id"], viewport["aria-labelledby"]
          assert_equal "-1", content["tabindex"]
          assert content.key?("data-closed"), "mounted-closed popup carries bare data-closed"
          refute content.key?("data-open")
          assert_equal "bottom", content["data-side"]
          assert_equal "start", content["data-align"]
          assert content.key?("hidden"), "closed content is hidden (truthful server render)"
          assert_equal "content", content["data-poetry--core--popper-target"]
          # focus-scope/dismissable/roving-focus are token-ACTIVATED by the
          # select controller on open - never server-rendered.
          assert_nil content["data-controller"]
        end

        def test_viewport_and_scroll_buttons_wrap_the_options_automatically
          html = render_select
          content = doc(html).css('[data-slot="select-content"]').first
          slots = content.elements.map { |node| node["data-slot"] }

          assert_equal %w[select-scroll-up-button select-viewport select-scroll-down-button], slots

          viewport = content.css('[data-slot="select-viewport"]').first

          assert_equal "scroll->poetry--core--select#syncScrollButtons", viewport["data-action"]
          assert_predicate viewport.css('[data-slot="select-item"]'), :any?

          content.css('[data-slot^="select-scroll-"]').each do |button|
            assert button.key?("hidden"), "scroll buttons render hidden; the controller owns visibility"
            assert_equal "true", button["aria-hidden"]
            assert_includes button["data-action"], "pointerenter->poetry--core--select#scrollHoldStart"
            assert_includes button["data-action"], "pointerleave->poetry--core--select#scrollHoldStop"
            assert_predicate button.css("svg"), :any?
          end
        end

        def test_items_are_role_option_divs_with_the_twin_selected_write
          html = render_select(value: "banana")
          apple, banana = doc(html).css('[data-slot="select-item"]').to_a

          assert_equal "div", apple.name, "options are divs, not buttons (APG/Radix-exact)"
          assert_equal "option", apple["role"]
          assert_equal "-1", apple["tabindex"]
          assert apple.key?("data-poetry-collection-item")
          assert_equal "apple", apple["data-value"]
          assert_equal "click->poetry--core--select#commit", apple["data-action"]
          # aria-selected and data-selected flip TOGETHER, never separately
          # (unselected = data-selected ABSENT - no data-unselected exists).
          assert_equal "false", apple["aria-selected"]
          refute apple.key?("data-selected")
          assert_equal "true", banana["aria-selected"]
          assert banana.key?("data-selected")
          assert_equal 1, doc(html).css('[data-slot="select-item"][aria-selected="true"]').size,
                       "exactly one option selected per non-nil value"

          indicator = banana.css('[data-slot="select-item-indicator"]').first

          assert indicator, "the check indicator ships built in (right gutter)"
          assert_equal "true", indicator.css("svg").first["aria-hidden"]
          assert_equal "Banana", banana.css('[data-slot="select-item-text"]').first.text,
                       "item-text is the node whose textContent becomes the display on commit"
        end

        def test_item_options_disabled_and_text_value
          html = render_select do |select|
            select.with_item(value: "up", text_value: "Move up") { "↑" }
            select.with_item(value: "api", disabled: true) { "API" }
          end
          icon_rich, disabled = doc(html).css('[data-slot="select-item"]').to_a

          assert_equal "Move up", icon_rich["data-text-value"]
          # divs have no native disabled: aria-disabled + data-disabled together.
          assert_equal "true", disabled["aria-disabled"]
          assert disabled.key?("data-disabled")
        end

        def test_text_value_feeds_the_native_option_label
          html = render_select(value: "up") do |select|
            select.with_item(value: "up", text_value: "Move up") { "↑" }
          end
          fragment = doc(html)

          assert_equal "Move up", fragment.css('[data-slot="select-native"] option[value="up"]').first.text
          assert_equal "Move up", fragment.css('[data-slot="select-value"]').first.text
        end

        def test_groups_wire_their_label_via_aria_labelledby
          html = render_select do |select|
            select.with_group(label: "Fruits") do |group|
              group.with_item(value: "apple") { "Apple" }
            end
            select.with_separator
            select.with_item(value: "other") { "Other" }
          end
          fragment = doc(html)
          group = fragment.css('[data-slot="select-group"]').first
          label = group.css('[data-slot="select-label"]').first
          separator = fragment.css('[data-slot="select-separator"]').first

          assert_equal "group", group["role"]
          assert_equal label["id"], group["aria-labelledby"]
          assert_equal "Fruits", label.text
          assert_nil label["role"], "label is a styled heading, no ARIA role (Radix-exact)"
          # Decorative inside a listbox: aria-hidden, no separator role
          # (only option/group children are valid; axe 2026-07-03).
          assert_equal "true", separator["aria-hidden"]
          assert_nil separator["role"]
          # Grouped options still land in the shared native select.
          assert_equal(%w[apple other],
                       fragment.css('[data-slot="select-native"] option:not([value=""])').map { |o| o["value"] })
        end

        def test_parts_are_ordered_as_declared
          html = render_select do |select|
            select.with_item(value: "a") { "A" }
            select.with_separator
            select.with_group(label: "G") { |group| group.with_item(value: "b") { "B" } }
          end
          slots = doc(html).css('[data-slot="select-viewport"] > [data-slot]').map { |node| node["data-slot"] }

          assert_equal %w[select-item select-separator select-group], slots
        end

        def test_open_state_is_server_rendered
          html = render_select(open: true)
          content = doc(html).css('[data-slot="select-content"]').first
          trigger = doc(html).css('[data-slot="select-trigger"]').first

          assert content.key?("data-open"), "open popup carries bare data-open"
          refute content.key?("data-closed")
          refute content.key?("hidden")
          assert_equal "true", trigger["aria-expanded"]
          assert trigger.key?("data-popup-open"), "open trigger carries bare data-popup-open"
        end

        def test_size_variant_is_a_data_attribute
          trigger = doc(render_select(size: :sm)).css('[data-slot="select-trigger"]').first

          assert_equal "sm", trigger["data-size"]
        end

        def test_disabled_disables_trigger_and_native_together
          fragment = doc(render_select(disabled: true))

          assert fragment.css('[data-slot="select-trigger"]').first.key?("disabled")
          assert fragment.css('[data-slot="select-native"]').first.key?("disabled")
        end

        def test_explicit_id_lands_on_the_trigger_with_derived_content_and_native_ids
          html = render_select(id: "order-fruit", "aria-describedby": "order-fruit-error",
                               "aria-invalid": "true")
          fragment = doc(html)
          trigger = fragment.css('[data-slot="select-trigger"]').first

          assert_equal "order-fruit", trigger["id"], "label[for] must reach the combobox"
          assert_equal "order-fruit-content", fragment.css('[data-slot="select-content"]').first["id"]
          assert_equal "order-fruit-native", fragment.css('[data-slot="select-native"]').first["id"]
          # Field control_attributes land on the TRIGGER, never the root.
          assert_equal "order-fruit-error", trigger["aria-describedby"]
          assert_equal "true", trigger["aria-invalid"]
          root = fragment.css('[data-slot="select"]').first

          assert_nil root["aria-describedby"]
          assert_nil root["aria-invalid"]
        end

        def test_rtl_sets_dir_on_the_root
          root = doc(render_select(dir: :rtl)).css('[data-slot="select"]').first

          assert_equal "rtl", root["dir"]
        end

        def test_unknown_value_falls_back_to_the_placeholder_display
          html = render_select(value: "kiwi")
          fragment = doc(html)

          assert_equal "Select a fruit", fragment.css('[data-slot="select-value"]').first.text
          assert fragment.css('[data-slot="select-trigger"]').first.key?("data-placeholder")
          assert_empty fragment.css('[data-slot="select-item"][aria-selected="true"]')
        end

        def test_duplicate_option_values_raise
          error = assert_raises(ArgumentError) do
            render_select do |select|
              select.with_item(value: "apple") { "Apple" }
              select.with_group(label: "More") { |group| group.with_item(value: "apple") { "Apple again" } }
            end
          end

          assert_includes error.message, "duplicate Select option value"
        end

        def test_blank_item_value_raises
          assert_raises(ArgumentError) do
            render_select { |select| select.with_item(value: "") { "Empty" } }
          end
        end

        def test_multiple_raises
          assert_raises(ArgumentError) { Component.new(multiple: true, "aria-label": "Fruit") }
        end

        def test_a_nameless_bare_select_fails_the_render
          error = assert_raises(ArgumentError) do
            render_inline(Component.new(placeholder: "Pick")) do |select|
              select.with_item(value: "a") { "A" }
            end
          end

          assert_includes error.message, "accessible name"
        end

        def test_an_explicit_id_counts_as_field_label_pairable
          html = render_inline(Component.new(id: "prefs-lang", placeholder: "Pick")) do |select|
            select.with_item(value: "en") { "English" }
          end.to_html

          assert_includes html, 'id="prefs-lang"'
        end

        def test_required_slot_guards
          assert_raises(ArgumentError, "missing items") do
            render_inline(Component.new("aria-label": "Fruit"))
          end
          assert_raises(ArgumentError, "empty group") do
            render_inline(Component.new("aria-label": "Fruit")) { |select| select.with_group(label: "G") }
          end
        end

        def test_source_exact_classes_land_on_the_parts
          html = render_select

          assert_includes html, "max-h-(--radix-select-content-available-height)"
          assert_includes html, "origin-(--radix-select-content-transform-origin)"
          assert_includes html, "min-w-[var(--radix-select-trigger-width)]"
          # The field chrome (placeholder dim, size heights) and the baked-in
          # popper translate nudges ride the theme rules.
          assert_includes html, "cn-select-trigger"
          assert_includes html, "cn-select-content"
        end
      end
    end
  end
end
