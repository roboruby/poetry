# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # Skills v1 money tests: the usage skill's family partition
    # covers the roster exactly, the generated files carry the load-bearing
    # content, and the curated design skill cannot drift from the surfaces
    # it teaches (theme roster, design-lint rule set).
    class SkillTest < ActiveSupport::TestCase
      DESIGN_DIR = Poetry::Ui.root.join("lib/generators/poetry/skill/templates/poetry-design")

      def skill_files
        @skill_files ||= Poetry::Ui.skill_files
      end

      test "every registry component lives in exactly one skill family" do
        mapped = SKILL_FAMILIES.values.flatten
        roster = Poetry::Ui.registry.entries.keys.map { |path| path.split("/").drop(2).join("_") }

        assert_equal roster.sort, mapped.sort,
                     "SKILL_FAMILIES must partition the registry exactly - map new components"
        assert_equal mapped.uniq, mapped, "no component may appear in two families"
      end

      test "the usage skill is a lean menu over one reference per family plus blocks" do
        expected = ["SKILL.md"] +
                   SKILL_FAMILIES.keys.map { |family| "references/#{family}.md" } +
                   ["references/blocks.md"]

        assert_equal expected, skill_files.keys,
                     "charts joins only in charts-installed hosts; this env has none"
      end

      test "the menu carries the census, the family index, and the taste pointer" do
        menu = skill_files.fetch("SKILL.md")
        registry = Poetry::Ui.registry

        assert_includes menu, "#{registry.entries.size} components + #{registry.blocks.size} blocks"
        SKILL_FAMILIES.each_key { |family| assert_includes menu, "(`references/#{family}.md`)" }
        assert_includes menu, "`poetry-design` skill"
        assert_includes menu, "kebab-case symbols"
        assert_includes menu, "bin/rails g poetry:block --list"
      end

      test "family references carry full contracts including agent rules" do
        forms = skill_files.fetch("references/forms.md")
        data = skill_files.fetch("references/data.md")

        assert_includes forms, "## button (`poetry_button`)"
        assert_includes data, "## badge (`poetry_badge`)"
        assert_includes data, "success|warning|info",
                        "the status vocabulary ships in the badge contract"
        assert_includes data, "- RULE:", "agent rules ship in the references"
      end

      test "the blocks reference inlines every block's source" do
        blocks = skill_files.fetch("references/blocks.md")

        Poetry::Ui.registry.blocks.each do |name, entry|
          assert_includes blocks, "## Block: #{entry["title"]} (`#{name}`)"
        end
        assert_includes blocks, "poetry_pagination", "block source is inlined, not summarized"
        refute_includes blocks, "poetry:block title=", "metadata headers are stripped"
      end

      test "the design skill's theme reference lists exactly the shipped themes" do
        theme_reference = DESIGN_DIR.join("references/theme.md").read
        shipped = Dir.glob(Poetry::Ui.root.join("themes/*.css").to_s)
                     .map { |file| File.basename(file, ".css") }.sort

        shipped.each do |theme|
          assert_includes theme_reference, "| `#{theme}` |",
                          "theme.md must describe every shipped theme"
        end
        listed = theme_reference.scan(/^\| `([a-z]+)` \|/).flatten.sort

        assert_equal shipped, listed, "theme.md must not describe themes that do not ship"
      end

      test "the design skill's audit reference names every design-lint rule" do
        audit_reference = DESIGN_DIR.join("references/audit.md").read

        Poetry::Core::DesignLint::RULES.each_key do |rule|
          assert_includes audit_reference, "`#{rule}`",
                          "audit.md must cover every design-lint rule - update it when rules land"
        end
      end

      test "both skill manifests carry valid names and descriptions" do
        usage = skill_files.fetch("SKILL.md")
        design = DESIGN_DIR.join("SKILL.md").read

        assert_match(/\A---\nname: poetry\n/, usage)
        assert_match(/\A---\nname: poetry-design\n/, design)
        [usage, design].each { |manifest| assert_match(/^description: >-\n/, manifest) }
      end
    end
  end
end
