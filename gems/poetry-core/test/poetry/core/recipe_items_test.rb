# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    class RecipeItemsTest < Minitest::Test
      def build(recipes)
        RecipeItems.new(recipes: recipes, gem_name: "poetry-test", gem_version: "0.0.1")
      end

      def skill_recipe
        {
          "name" => "skill-demo",
          "title" => "Demo skill",
          "description" => "A demo skill bundle.",
          "files" => lambda {
            [{ "path" => "SKILL.md", "target" => ".claude/skills/demo/SKILL.md", "content" => "# demo" }]
          }
        }
      end

      def test_item_matches_the_registry_item_schema_shape
        item = build([skill_recipe]).item("skill-demo")

        assert_equal RegistryItems::ITEM_SCHEMA, item["$schema"]
        assert_equal "registry:block", item["type"]
        assert_equal "recipe", item.dig("meta", "kind")
        assert_equal "copy-in", item.dig("meta", "provided")
        assert_equal "poetry-test", item.dig("meta", "gem")

        file = item["files"].first

        assert_equal "registry:file", file["type"]
        assert_equal ".claude/skills/demo/SKILL.md", file["target"]
        assert_equal "# demo", file["content"]
      end

      def test_files_callables_evaluate_lazily_per_item_build
        calls = 0
        recipe = skill_recipe.merge("files" => lambda {
          calls += 1
          [{ "path" => "a", "target" => "a.md", "content" => "x" }]
        })
        items = build([recipe])

        assert_equal 0, calls
        items.item("skill-demo")
        items.item("skill-demo")

        assert_equal 2, calls
      end

      def test_summaries_strip_content_but_keep_targets
        summary = build([skill_recipe]).summaries.first

        refute summary["files"].first.key?("content")
        assert_equal ".claude/skills/demo/SKILL.md", summary["files"].first["target"]
      end

      def test_unsafe_targets_are_rejected
        %w[/etc/passwd ../up lib/../../out].each do |target|
          recipe = skill_recipe.merge("files" => [{ "path" => "a", "target" => target, "content" => "x" }])

          error = assert_raises(Error) { build([recipe]).item("skill-demo") }
          assert_includes error.message, "unsafe target"
        end
      end

      def test_name_collisions_raise
        assert_raises(Error) { build([skill_recipe, skill_recipe]).names }
      end

      def test_unknown_item_is_nil_and_names_sort
        items = build([skill_recipe])

        assert_nil items.item("nope")
        assert_equal ["skill-demo"], items.names
      end
    end
  end
end
