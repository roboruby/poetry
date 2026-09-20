# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    module HTML
      class AttributesTest < Minitest::Test
        def test_merge_classes_returns_merged_string
          attrs = Attributes.new(class: "btn")
          merged = attrs.merge_classes("btn-primary")

          assert_equal "btn btn-primary", merged["class"]
        end

        def test_merge_classes_is_non_mutating
          attrs = Attributes.new(class: "btn")
          attrs.merge_classes("btn-primary")

          assert_equal "btn", attrs["class"]
        end

        def test_merge_classes_resolves_tailwind_conflicts_last_wins
          attrs = Attributes.new(class: "text-sm")
          merged = attrs.merge_classes("text-lg")

          assert_equal "text-lg", merged["class"]
        end

        def test_merge_classes_filters_blank_values
          attrs = Attributes.new(class: nil)
          merged = attrs.merge_classes("p-4", nil, "")

          assert_equal "p-4", merged["class"]
        end

        def test_merge_if_not_set_treats_a_nil_simple_attribute_as_unset
          # Component#html_attributes always seeds class: (nil when the
          # dictionary base is empty) - a nil must not block the default,
          # or a root part's classes silently vanish (the Sidebar wrapper
          # bug the poetry-docs shell caught).
          attrs = Attributes.new(class: nil)
          merged = attrs.merge_if_not_set("class" => "flex min-h-svh", "id" => "x")

          assert_equal "flex min-h-svh", merged.to_attributes["class"]
          assert_equal "x", merged.to_attributes["id"]

          set = Attributes.new(class: "mine")
          kept = set.merge_if_not_set("class" => "default")

          assert_equal "mine", kept.to_attributes["class"], "a real value still wins"
        end

        def test_to_attributes_renders_boolean_attribute
          attrs = Attributes.new(disabled: true, hidden: false)
          result = attrs.to_attributes

          assert_equal "disabled", result["disabled"]
          refute result.key?("hidden")
        end

        def test_to_attributes_flattens_nested_data
          attrs = Attributes.new(data: { controller: "dropdown", id: 1 })
          result = attrs.to_attributes

          assert_equal "dropdown", result["data-controller"]
          assert_equal "1", result["data-id"]
        end

        # --- stimulus keys concatenate through merge_if_not_set ---
        # (the host-attached-controller contract: components compose roots
        # via merge_if_not_set(defaults), and a caller's own
        # data-controller/action must never disconnect the component's)

        def test_merge_if_not_set_concatenates_caller_and_default_controllers
          attrs = Attributes.new(data: { controller: "host-thing" })
          attrs.merge_if_not_set!("data-controller" => "poetry--core--tabs")

          assert_equal "host-thing poetry--core--tabs", attrs["data"]["controller"]
        end

        def test_merge_if_not_set_concatenates_controllers_in_the_flat_spelling
          attrs = Attributes.new("data-controller" => "host-thing")
          attrs.merge_if_not_set!(data: { controller: "poetry--core--tabs" })

          assert_equal "host-thing poetry--core--tabs", attrs["data"]["controller"]
        end

        def test_merge_if_not_set_concatenates_actions_and_keeps_caller_first
          attrs = Attributes.new(data: { action: "click->host#track" })
          attrs.merge_if_not_set!(data: { action: "click->poetry--core--tabs#activate" })

          assert_equal "click->host#track click->poetry--core--tabs#activate",
                       attrs["data"]["action"]
        end

        def test_merge_if_not_set_deduplicates_stimulus_tokens
          attrs = Attributes.new(data: { controller: "poetry--core--tabs" })
          attrs.merge_if_not_set!(data: { controller: "poetry--core--tabs", action: "click->a#b" })

          assert_equal "poetry--core--tabs", attrs["data"]["controller"]
          assert_equal "click->a#b", attrs["data"]["action"]
        end

        def test_merge_if_not_set_sets_default_stimulus_keys_when_caller_has_none
          attrs = Attributes.new(class: "w-full")
          attrs.merge_if_not_set!("data-controller" => "poetry--core--tabs")

          assert_equal "poetry--core--tabs", attrs["data"]["controller"]
        end

        def test_merge_if_not_set_keeps_other_data_keys_first_wins
          attrs = Attributes.new(data: { side: "top" })
          attrs.merge_if_not_set!(data: { side: "bottom", slot: "content" })

          assert_equal "top", attrs["data"]["side"]
          assert_equal "content", attrs["data"]["slot"]
        end

        # --- spelling-aliasing rules: plain merge + to_attributes ---
        # (both spellings of one attribute must never race by insertion
        # order: stimulus wiring concatenates, other dupes are
        # flat-spelling-wins)

        def test_plain_merge_concatenates_flat_data_controller_on_conflict
          attrs = Attributes.new("data-controller" => "host-thing")
          merged = attrs.merge("data-controller" => "poetry--core--tabs")

          assert_equal "host-thing poetry--core--tabs", merged["data-controller"]
        end

        def test_plain_merge_concatenates_flat_data_action_on_conflict
          attrs = Attributes.new("data-action" => "click->host#track")
          merged = attrs.merge("data-action" => "click->tabs#activate")

          assert_equal "click->host#track click->tabs#activate", merged["data-action"]
        end

        def test_plain_merge_still_clobbers_other_flat_data_keys
          attrs = Attributes.new("data-side" => "top")
          merged = attrs.merge("data-side" => "bottom")

          assert_equal "bottom", merged["data-side"]
        end

        def test_to_attributes_concatenates_double_spelled_stimulus_keys
          flat_first = Attributes.new("data-controller" => "host-thing",
                                      data: { controller: "poetry--core--tabs" })
          nested_first = Attributes.new(data: { controller: "poetry--core--tabs" },
                                        "data-controller" => "host-thing")

          assert_equal "host-thing poetry--core--tabs",
                       flat_first.to_attributes["data-controller"]
          assert_equal ["host-thing", "poetry--core--tabs"],
                       nested_first.to_attributes["data-controller"].split.sort
        end

        def test_to_attributes_resolves_other_double_spellings_flat_wins
          flat_first = Attributes.new("data-side" => "top", data: { side: "bottom" })
          nested_first = Attributes.new(data: { side: "bottom" }, "data-side" => "top")

          assert_equal "top", flat_first.to_attributes["data-side"]
          assert_equal "top", nested_first.to_attributes["data-side"]
        end

        def test_to_attributes_resolves_aria_double_spellings_flat_wins
          attrs = Attributes.new(aria: { label: "Nested" }, "aria-label" => "Flat")

          assert_equal "Flat", attrs.to_attributes["aria-label"]
        end

        def test_merge_if_not_set_unifies_a_double_spelled_caller_controller
          attrs = Attributes.new(data: { controller: "host-a" }, "data-controller" => "host-b")
          attrs.merge_if_not_set!("data-controller" => "poetry--core--tabs")

          assert_equal ["host-a", "host-b", "poetry--core--tabs"],
                       attrs["data"]["controller"].split.sort
        end

        # --- Attributes.merged: the wiring-plus-caller combining recipe ---

        def test_merged_concatenates_wiring_and_caller_stimulus_keys
          result = Attributes.merged(
            { "data-controller" => "poetry--core--menu", "data-action" => "click->menu#activate" },
            { data: { controller: "host-thing", action: "click->host#track" } }
          )

          assert_equal "poetry--core--menu host-thing", result["data-controller"]
          assert_equal "click->menu#activate click->host#track", result["data-action"]
        end

        def test_merged_tailwind_merges_classes_and_keeps_caller_extras
          result = Attributes.merged(
            { "class" => "px-2 text-sm", "data-slot" => "menu-item" },
            { class: "px-4", "aria-label" => "Save" }
          )

          assert_equal "text-sm px-4", result["class"]
          assert_equal "menu-item", result["data-slot"]
          assert_equal "Save", result["aria-label"]
        end

        def test_merged_skips_nils_and_returns_flat_attributes
          result = Attributes.merged({ "data-side" => "top" }, nil, { role: "menuitem" })

          assert_equal "top", result["data-side"]
          assert_equal "menuitem", result["role"]
          refute result.key?("data"), "output is flat, render-ready"
        end
      end
    end
  end
end
