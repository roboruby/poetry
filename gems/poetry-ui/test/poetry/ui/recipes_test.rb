# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    class RecipesTest < ActiveSupport::TestCase
      def items
        Poetry::Ui.recipe_items
      end

      test "the roster projects all recipes with valid items" do
        assert_equal %w[agent-embed scaffold-templates screen-data-index screen-settings
                        skill-poetry skill-poetry-component skill-poetry-design], items.names

        items.names.each do |name|
          item = items.item(name)

          assert_equal "recipe", item.dig("meta", "kind"), name
          assert_equal "poetry-ui", item.dig("meta", "gem"), name
          assert_predicate item["files"], :any?, "#{name} has no files"
          item["files"].each do |file|
            assert_predicate file["content"], :present?, "#{name} ships an empty #{file["path"]}"
            assert_predicate Pathname.new(file["target"]), :relative?, "#{name} target not relative"
          end
        end
      end

      test "skill bundles mirror the generator-installed files" do
        skill = items.item("skill-poetry")
        targets = skill["files"].map { |file| file["target"] }

        assert_includes targets, ".claude/skills/poetry/SKILL.md"
        assert_includes targets, ".claude/skills/poetry/references/deciding.md"
        assert_equal Poetry::Ui.runtime_skill_files.size, skill["files"].size
      end

      test "scaffold-templates targets mirror the scaffold_templates generator" do
        require "generators/poetry/scaffold_templates/scaffold_templates_generator"
        targets = items.item("scaffold-templates")["files"].map { |file| file["target"] }

        Poetry::ScaffoldTemplatesGenerator::VIEW_TEMPLATES.each do |name|
          assert_includes targets, "lib/templates/erb/scaffold/#{name}.html.erb.tt"
        end
        assert_includes targets, "lib/templates/rails/scaffold_controller/controller.rb.tt"
        assert_equal Poetry::ScaffoldTemplatesGenerator::VIEW_TEMPLATES.size + 1, targets.size
      end

      test "screen recipes depend only on real blocks and target app paths" do
        gem_blocks = YAML.safe_load_file(
          Poetry::Ui.root.join(Poetry::Core::Registry::RELATIVE_PATH)
        )["blocks"].keys

        %w[screen-data-index screen-settings].each do |name|
          item = items.item(name)

          assert_predicate item["registryDependencies"], :any?, "#{name} composes no blocks"
          item["registryDependencies"].each do |dep|
            assert_includes gem_blocks, dep, "#{name} depends on unknown block #{dep}"
          end

          targets = item["files"].map { |file| file["target"] }

          assert(targets.any? { |t| t.start_with?("app/controllers/") }, "#{name} ships no controller")
          assert(targets.any? { |t| t.start_with?("app/views/") }, "#{name} ships no view")
          assert(targets.any? { |t| t.start_with?("test/system/") }, "#{name} ships no system test")
          assert_includes item["description"], "to routes", "#{name} must state its route line"
        end
      end
    end
  end
end
