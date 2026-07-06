# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module RadioGroup
      class ComponentTest < ViewComponent::TestCase
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def render_group(**options)
          render_inline(Component.new(name: "plan", label: "Plan", **options)) do |group|
            group.with_item(value: "monthly", label: "Monthly")
            group.with_item(value: "yearly", label: "Yearly")
            group.with_item(value: "lifetime", label: "Lifetime")
          end.to_html
        end

        def test_the_radiogroup_anatomy_renders_with_both_machines_on_one_root
          fragment = doc(render_group)
          root = fragment.css('[data-slot="radio-group"]').first

          assert_equal "radiogroup", root["role"]
          assert_equal "radio_group", root["data-component"]
          assert_equal "Plan", root["aria-label"]
          # BOTH controllers token-concatenate on the one root (the
          # Accordion composition shape).
          assert_equal "poetry--core--radio-group poetry--core--roving-focus", root["data-controller"]
          # orientation both (APG radio: all four arrows) + loop, DEFAULT
          # tabindex-managing mode (no manage-tabindex value rendered).
          assert_equal "both", root["data-poetry--core--roving-focus-orientation-value"]
          assert_equal "true", root["data-poetry--core--roving-focus-loop-value"]
          assert_nil root["data-poetry--core--roving-focus-manage-tabindex-value"]
          # Selection-follows-focus: the entry hook + the roving keydown.
          assert_includes root["data-action"],
                          "poetry--core--roving-focus:entry->poetry--core--radio-group#entryCheck"
          assert_includes root["data-action"], "keydown->poetry--core--roving-focus#keydown"
        end

        def test_items_are_role_radio_buttons_with_the_checked_projection
          fragment = doc(render_group(value: "yearly"))
          items = fragment.css('[data-slot="radio-group-item"]')

          assert_equal 3, items.size
          items.each do |item|
            assert_equal "button", item.name
            assert_equal "button", item["type"]
            assert_equal "radio", item["role"]
            assert item.key?("data-poetry-collection-item")
            assert_equal "click->poetry--core--radio-group#check", item["data-action"]
          end
          checked = items.find { |item| item["data-value"] == "yearly" }

          assert_equal "true", checked["aria-checked"]
          # Base UI checked pair: bare data-checked / data-unchecked.
          assert checked.key?("data-checked")
          refute checked.key?("data-unchecked")
          refute checked.css('[data-slot="radio-group-indicator"]').first.key?("hidden"),
                 "the checked indicator is visible"
          unchecked = items.find { |item| item["data-value"] == "monthly" }

          assert_equal "false", unchecked["aria-checked"]
          assert unchecked.key?("data-unchecked")
          refute unchecked.key?("data-checked")
          assert unchecked.css('[data-slot="radio-group-indicator"]').first.key?("hidden")
        end

        def test_the_server_renders_the_roving_tab_stop_on_the_checked_item
          items = doc(render_group(value: "yearly")).css('[data-slot="radio-group-item"]')

          assert_equal(%w[-1 0 -1], items.map { |item| item["tabindex"] },
                       "one Tab stop - the checked item - BEFORE JS connects")
        end

        def test_nothing_checked_falls_back_to_the_first_enabled_item
          items = doc(render_group).css('[data-slot="radio-group-item"]')

          assert_equal(%w[0 -1 -1], items.map { |item| item["tabindex"] })
          assert_equal(%w[false false false], items.map { |item| item["aria-checked"] })
        end

        def test_one_hidden_native_radio_per_item_with_the_shared_name
          fragment = doc(render_group(value: "monthly"))
          inputs = fragment.css('input[type="radio"]')

          assert_equal 3, inputs.size
          assert_equal(%w[plan plan plan], inputs.map { |input| input["name"] },
                       "shared name - native radio serialization, collection_radio_buttons-identical")
          assert_equal(%w[monthly yearly lifetime], inputs.map { |input| input["value"] })
          inputs.each do |input|
            assert_equal "true", input["aria-hidden"]
            assert_equal "-1", input["tabindex"], "never a second Tab stop"
            assert_includes input["class"], "sr-only"
          end
          assert inputs.first.key?("checked")
          assert_equal(1, inputs.count { |input| input.key?("checked") })
          # NO root hidden input: nothing submits when none is checked.
          assert_empty fragment.css('input[type="hidden"]')
        end

        def test_item_labels_render_the_pairing_row_wired_to_the_button_id
          fragment = doc(render_group)
          item = fragment.css('[data-slot="radio-group-item"]').first
          label = fragment.css("label").first

          assert_equal item["id"], label["for"], "label for= targets the BUTTON id (label click checks)"
          assert_equal "Monthly", label.text
        end

        def test_duplicate_item_values_raise
          assert_raises(ArgumentError) do
            render_inline(Component.new(name: "plan", label: "Plan")) do |group|
              group.with_item(value: "monthly", label: "Monthly")
              group.with_item(value: "monthly", label: "Again")
            end
          end
        end

        def test_an_unlabelled_group_raises
          error = assert_raises(ArgumentError) do
            render_inline(Component.new(name: "plan")) do |group|
              group.with_item(value: "monthly", label: "Monthly")
            end
          end

          assert_includes error.message, "unlabelled RadioGroup"
        end

        def test_aria_labelledby_counts_as_labelled
          html = render_inline(Component.new(name: "plan", "aria-labelledby": "plan-heading")) do |group|
            group.with_item(value: "monthly", label: "Monthly")
          end.to_html

          assert_includes html, 'aria-labelledby="plan-heading"'
        end

        def test_an_empty_group_raises
          assert_raises(ArgumentError) { render_inline(Component.new(name: "plan", label: "Plan")) }
        end

        def test_disabled_items_render_native_disabled_and_the_collection_filter
          fragment = doc(render_inline(Component.new(name: "plan", label: "Plan")) do |group|
            group.with_item(value: "monthly", label: "Monthly", disabled: true)
            group.with_item(value: "yearly", label: "Yearly")
          end.to_html)
          disabled = fragment.css('[data-slot="radio-group-item"]').first

          assert disabled.key?("disabled")
          assert disabled.key?("data-disabled")
          # The input is the button's SIBLING (nested-interactive fix) -
          # find it by the shared item id.
          assert fragment.css(%(input[id="#{disabled["id"]}-input"])).first.key?("disabled")
          # The tab-stop fallback skips the disabled item.
          assert_equal "-1", disabled["tabindex"]
          assert_equal "0", fragment.css('[data-slot="radio-group-item"]').last["tabindex"]
        end

        def test_root_disabled_disables_every_item
          fragment = doc(render_group(disabled: true))
          root = fragment.css('[data-slot="radio-group"]').first

          assert root.key?("data-disabled")
          assert(fragment.css('[data-slot="radio-group-item"]').all? { |item| item.key?("disabled") })
          assert(fragment.css("input").all? { |input| input.key?("disabled") })
        end

        def test_required_is_aria_only_on_the_root
          fragment = doc(render_group(required: true))

          assert_equal "true", fragment.css('[data-slot="radio-group"]').first["aria-required"]
          assert(fragment.css("input").none? { |input| input.key?("required") },
                 "never native required on aria-hidden inputs (the /Field rule)")
        end

        def test_invalid_marks_every_item_aria_invalid
          items = doc(render_group(invalid: true)).css('[data-slot="radio-group-item"]')

          assert(items.all? { |item| item["aria-invalid"] == "true" })
        end

        def test_source_exact_classes_land_on_root_item_indicator_and_dot
          fragment = doc(render_group(value: "monthly"))

          assert_includes fragment.css('[data-slot="radio-group"]').first["class"], "cn-radio-group"
          item_class = fragment.css('[data-slot="radio-group-item"]').first["class"]

          %w[cn-radio-group-item aspect-square border outline-none].each do |token|
            assert_includes item_class, token
          end
          indicator = fragment.css('[data-slot="radio-group-indicator"]').first

          assert_includes indicator["class"], "items-center"
          dot = indicator.css("svg").first

          %w[cn-radio-group-indicator-icon -translate-x-1/2].each { |token| assert_includes dot["class"], token }
          assert_equal "true", dot["aria-hidden"]
        end

        def test_item_values_slug_into_ids_and_caller_classes_merge
          fragment = doc(render_inline(Component.new(name: "q", label: "Q", id: "quality")) do |group|
            group.with_item(value: "hi res/4k!", label: "4K", class: "size-5")
          end.to_html)
          item = fragment.css('[data-slot="radio-group-item"]').first

          assert_equal "quality-hi-res-4k-", item["id"], "no raw user string becomes an id"
          assert_includes item["class"], "size-5"
          refute_includes item["class"], "size-4"
        end
      end
    end
  end
end
