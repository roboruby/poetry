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

      # The triggering + finishing doctrine (the leads): the
      # design skill's description must relevance-match BUILD tasks (it fired
      # zero times in 31 brief-shaped arms when scoped to "design" asks), the
      # usage skill must hand off to it before page composition, and both
      # finishing surfaces must state check-LAST, not check-sometime.
      test "the design skill triggers on build tasks and the usage skill hands off" do
        usage = skill_files.fetch("SKILL.md")
        design_description = DESIGN_DIR.join("SKILL.md").read[/\A---\n.*?\n---\n/m]

        assert_includes design_description, "WHENEVER building",
                        "the description must match brief-shaped build tasks"
        refute_match(/not which\s+component to call/, design_description,
                     "the self-scoping-out clause must never return")
        assert_includes usage, "## Composing a page? Load poetry-design"
        assert_includes usage, "BEFORE composing"
      end

      test "the finishing doctrine is check-LAST on every surface" do
        usage = skill_files.fetch("SKILL.md")
        audit_reference = DESIGN_DIR.join("references/audit.md").read

        assert_includes usage, "Check comes LAST"
        assert_includes usage, "after\n  your last edit",
                        "the guardrail must order check after the final edit"
        assert_includes audit_reference, "AFTER the final edit"
      end

      # The default-path doctrine (the lead): compose is the
      # UNCONDITIONAL first move on every surface - measured the
      # conditional form ("starting a new SCREEN?") at 3/31 blocks-surface
      # adoption while the unconditional check-LAST doctrine hit 26/31.
      test "compose is the unconditional first move on every text surface" do
        usage = skill_files.fetch("SKILL.md")
        compose_reference = DESIGN_DIR.join("references/compose.md").read
        agents = Class.new { include Poetry::Generators::AgentsSection }.new.agents_section

        assert_match(/## Guardrails\s+- FIRST MOVE, for every brief/, usage,
                     "the compose first-move rule must LEAD the guardrails")
        refute_includes usage, "Starting a new SCREEN?",
                        "the conditional trigger that never fired is retired"
        assert_includes agents, "FIRST MOVE on any UI brief"
        assert_includes agents, "required slots"
        assert_includes compose_reference, "## Step 1 is a tool call, not a decision"
        assert_includes compose_reference, "START FROM THAT SOURCE"
      end

      test "block headers carry the compose routing keywords" do
        Poetry::Ui.registry.blocks.each do |name, entry|
          assert_kind_of Array, entry["keywords"],
                         "#{name} needs keywords= in its poetry:block header - compose routes by them"
          assert_operator entry["keywords"].size, :>=, 2,
                          "#{name} keywords are the routing surface, not decoration"
        end
      end
    end
  end
end
