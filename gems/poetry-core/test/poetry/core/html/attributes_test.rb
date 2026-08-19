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
      end
    end
  end
end
