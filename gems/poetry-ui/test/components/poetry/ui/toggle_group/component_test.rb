# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module ToggleGroup
      class ComponentTest < ViewComponent::TestCase
        def doc(html)
          Nokogiri::HTML5.fragment(html)
        end

        def render_group(**, &block)
          block ||= lambda { |group|
            group.with_item(value: "bold", label: "Toggle bold") { "B" }
            group.with_item(value: "italic", label: "Toggle italic") { "I" }
            group.with_item(value: "underline", label: "Toggle underline") { "U" }
          }
          render_inline(Component.new(label: "Formatting", **), &block).to_html
        end

        def test_single_renders_radiogroup_semantics_with_aria_pressed_stripped
          fragment = doc(render_group(type: :single, value: "italic"))
          root = fragment.css('[data-slot="toggle-group"]').first
          items = fragment.css('[data-slot="toggle-group-item"]')

          assert_equal "toggle_group", root["data-component"]
          assert_equal "radiogroup", root["role"]
          assert_equal "Formatting", root["aria-label"]
          assert_equal 3, items.size
          items.each do |item|
            assert_equal "radio", item["role"]
            assert_nil item["aria-pressed"], "single strips aria-pressed (the Radix {aria-pressed: undefined} strip)"
          end
          assert_equal(%w[false true false], items.map { |item| item["aria-checked"] })
          # Base UI presence boolean: pressed = bare data-pressed, unpressed = absent.
          assert_equal([false, true, false], items.map { |item| item.key?("data-pressed") })
        end

        def test_multiple_renders_toolbar_semantics_with_aria_checked_absent
          fragment = doc(render_group(type: :multiple, values: %w[bold underline]))
          root = fragment.css('[data-slot="toggle-group"]').first
          items = fragment.css('[data-slot="toggle-group-item"]')

          assert_equal "toolbar", root["role"]
          items.each do |item|
            assert_nil item["role"]
            assert_nil item["aria-checked"], "multiple wears the toggle-button vocabulary only"
          end
          assert_equal(%w[true false true], items.map { |item| item["aria-pressed"] })
          assert_equal([true, false, true], items.map { |item| item.key?("data-pressed") })
        end

        def test_both_machines_ride_one_attributes_instance_on_the_root
          root = doc(render_group(type: :single, orientation: :horizontal)).css('[data-slot="toggle-group"]').first

          # Token-concatenated, not overwritten (the Accordion lesson).
          assert_equal "poetry--core--toggle-group poetry--core--roving-focus", root["data-controller"]
          assert_equal "single", root["data-poetry--core--toggle-group-type-value"]
          # DEFAULT tabindex-managing mode: no manage-tabindex=false value.
          assert_nil root["data-poetry--core--roving-focus-manage-tabindex-value"]
          assert_equal "horizontal", root["data-poetry--core--roving-focus-orientation-value"]
          assert_equal "true", root["data-poetry--core--roving-focus-loop-value"]
          assert_equal "keydown->poetry--core--roving-focus#keydown", root["data-action"]
          assert_equal "horizontal", root["data-orientation"]
        end

        def test_items_are_dumb_collection_buttons_under_the_group_machine
          items = doc(render_group).css('[data-slot="toggle-group-item"]')

          items.each do |item|
            assert_equal "button", item["type"]
            assert item.key?("data-poetry-collection-item"), "roving-focus finds items via collection.js"
            assert_equal "click->poetry--core--toggle-group#toggle", item["data-action"]
            assert_nil item["data-controller"], "no per-item poetry--core--pressed - one owner, no event soup"
          end
          assert_equal(%w[bold italic underline], items.map { |item| item["data-value"] })
        end

        def test_the_root_cascades_variant_size_spacing_to_item_data_attributes
          fragment = doc(render_group(type: :multiple, variant: :outline, size: :sm, spacing: 2))
          root = fragment.css('[data-slot="toggle-group"]').first
          item = fragment.css('[data-slot="toggle-group-item"]').first

          assert_equal "outline", root["data-variant"]
          assert_equal "sm", root["data-size"]
          assert_equal "2", root["data-spacing"]
          assert_equal "--gap: 2", root["style"]
          # ROOT WINS (the source's context.variant || item rule): items
          # mirror the root's axes.
          assert_equal "outline", item["data-variant"]
          assert_equal "sm", item["data-size"]
          assert_equal "2", item["data-spacing"]
        end

        def test_item_classes_are_shared_from_toggles_dictionary_not_copied
          item = doc(render_group(variant: :outline)).css('[data-slot="toggle-group-item"]').first

          # Toggle's base + outline variant (via Toggle::Style)...
          %w[cn-toggle cn-toggle-variant-outline focus-visible:ring-[3px]].each do |token|
            assert_includes item["class"], token
          end
          # ...plus the group's item overrides (min-w-0 inline beats the
          # themed min-w-9 by layer order; px-3 rides cn-toggle-group-item,
          # later in the theme than Toggle's sizes, so it wins in-layer).
          # The whole segment-radius cluster (rounded-none + edge radii)
          # rides the theme since N12 W2 - split-side rule.
          %w[w-auto min-w-0 cn-toggle-group-item focus:z-10
             data-[spacing=0]:data-[variant=outline]:border-l-0].each do |token|
            assert_includes item["class"], token
          end
          refute_includes item["class"], "data-[spacing=0]:rounded-none"
          refute_includes item["class"], "min-w-9"
          refute_includes item["class"], "px-2 "
          # ...and the group dictionary never duplicates Toggle's strings
          # (shared, not copied - the CI skew guard).
          refute_includes Style.resolver.all_classes, "data-pressed:bg-accent"
        end

        def test_the_group_root_carries_the_source_classes_and_gap_var
          root = doc(render_group).css('[data-slot="toggle-group"]').first

          %w[flex w-fit items-center cn-toggle-group].each do |token|
            assert_includes root["class"], token
          end
          # The group/toggle-group marker is LIVE again (2026-08-14): the
          # orientation-guarded segment chains - border-l/t collapse in the
          # dictionary, first/last radii in every theme - consume it.
          assert_includes root["class"], "group/toggle-group"
          assert_includes root["class"], "data-vertical:flex-col"
          assert_includes root["class"], "gap-[--spacing(var(--gap))]"
          # The dead-in-source selector rides .cn-toggle-group in the theme
          # (still ported verbatim + flagged there).
        end

        def test_disabled_cascades_to_every_item_and_marks_the_root
          fragment = doc(render_group(disabled: true))
          root = fragment.css('[data-slot="toggle-group"]').first

          assert root.key?("data-disabled")
          fragment.css('[data-slot="toggle-group-item"]').each do |item|
            assert item.key?("disabled")
            assert item.key?("data-disabled"), "the roving-focus collection filter"
          end
        end

        def test_a_disabled_item_is_marked_for_the_roving_filter
          html = render_group(type: :single) do |group|
            group.with_item(value: "a") { "A" }
            group.with_item(value: "b", disabled: true) { "B" }
          end
          items = doc(html).css('[data-slot="toggle-group-item"]')

          refute items.first.key?("disabled")
          assert items.last.key?("disabled")
          assert items.last.key?("data-disabled")
        end

        def test_value_and_values_are_type_locked
          error = assert_raises(ArgumentError) { Component.new(type: :single, values: %w[a]) }

          assert_match(/single takes value:/, error.message)

          error = assert_raises(ArgumentError) { Component.new(type: :multiple, value: "a") }

          assert_match(/multiple takes values:/, error.message)

          assert_raises(ArgumentError) { Component.new(type: :radio) }
        end

        def test_duplicate_item_values_raise
          error = assert_raises(ArgumentError) do
            render_group do |group|
              group.with_item(value: "bold") { "B" }
              group.with_item(value: "bold") { "B again" }
            end
          end

          assert_match(/duplicate ToggleGroup item value "bold"/, error.message)
        end

        def test_icon_only_item_without_label_raises
          error = assert_raises(ArgumentError) do
            render_group do |group|
              group.with_item(value: "bold") { '<svg viewBox="0 0 24 24"></svg>'.html_safe }
            end
          end

          assert_match(/icon-only ToggleGroup item "bold" requires label:/, error.message)
        end

        def test_a_group_without_items_raises
          assert_raises(ArgumentError) { render_inline(Component.new(label: "Empty")) }
        end

        def test_a_nameless_group_trips_the_lint_warning
          warnings = capture_rails_warnings do
            render_inline(Component.new) { |group| group.with_item(value: "a") { "A" } }
          end

          assert_equal 1, warnings.size
          assert_includes warnings.first, "nameless radiogroup"
          assert_empty(capture_rails_warnings { render_group })
        end

        def test_no_form_machinery_exists
          html = render_group(type: :single, value: "bold")

          assert_empty doc(html).css("input"), "group pressed state is UI state - no hidden inputs"
          refute Component.has_option_attribute?(:name), "no name: - submitting selection is RadioGroup territory"
        end

        def test_the_caller_can_override_the_role_for_toolbar_composition
          root = doc(render_group(type: :multiple, role: "group")).css('[data-slot="toggle-group"]').first

          # The Radix Toolbar.ToggleGroup escape: role passthrough wins.
          assert_equal "group", root["role"]
        end
      end
    end
  end
end
