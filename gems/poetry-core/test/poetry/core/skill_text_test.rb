# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Poetry
  module Core
    # SkillText (Skills v1): the component-usage skill is generated
    # from the registry as a lean SKILL.md menu over per-family reference
    # files. These tests pin the file map and each file's load-bearing
    # content with a minimal registry double; the real-roster coverage
    # (every component in exactly one family) is gated in poetry-ui, where
    # the roster lives.
    class SkillTextTest < Minitest::Test
      FakeRegistry = Data.define(:entries, :blocks, :source_root)

      BADGE_ENTRY = {
        "class_name" => "Poetry::Ui::Badge::Component",
        "bem_block" => "cn-badge",
        "styles" => [{ "name" => "variant", "variants" => %w[default success] }],
        "options" => [],
        "slots" => [],
        "agent_rules" => ["Status badges on one surface read as a SET."]
      }.freeze

      TEMPLATE = <<~ERB
        <%# poetry:block title="Data index" description="A records screen." %>
        <section><%= poetry_badge { "Fulfilled" } %></section>
      ERB

      def with_registry
        Dir.mktmpdir("skill-text") do |dir|
          Pathname(dir).join("blocks").mkpath
          Pathname(dir).join("blocks/data_index.html.erb").write(TEMPLATE)
          yield FakeRegistry.new(
            entries: { "poetry/ui/badge" => BADGE_ENTRY },
            blocks: { "data-index" => { "title" => "Data index", "description" => "A records screen.",
                                        "components" => %w[badge], "template" => "blocks/data_index.html.erb" } },
            source_root: Pathname(dir)
          )
        end
      end

      def skill(registry, charts_registry: nil)
        SkillText.new(registry: registry, families: { "data" => %w[badge] },
                      charts_registry: charts_registry)
      end

      def test_files_map_covers_menu_families_and_blocks
        with_registry do |registry|
          assert_equal ["SKILL.md", "references/data.md", "references/blocks.md"],
                       skill(registry).files.keys
        end
      end

      def test_skill_md_is_a_lean_menu_with_guardrails_census_and_index
        with_registry do |registry|
          menu = skill(registry).files.fetch("SKILL.md")

          assert_includes menu, "name: poetry"
          assert_includes menu, "1 components + 1 blocks"
          assert_includes menu, "- **data** (`references/data.md`): badge"
          assert_includes menu, "- **blocks** (`references/blocks.md`): data-index"
          assert_includes menu, "kebab-case symbols"
          assert_includes menu, "`poetry-design` skill"
          refute_includes menu, "cn-badge", "contracts live in references, not the menu"
        end
      end

      # The first-move doctrine: compose is unconditional and leads
      # the guardrails - the lesson that a conditional trigger
      # ("starting a new SCREEN?") never fires because agents see
      # components in the brief, not screens.
      def test_skill_md_leads_with_the_unconditional_compose_first_move
        with_registry do |registry|
          menu = skill(registry).files.fetch("SKILL.md")
          guardrails = menu[/## Guardrails.*?## Find your component/m]

          assert_match(/\A## Guardrails\s+- FIRST MOVE, for every brief/, guardrails)
          assert_includes guardrails, "`compose` tool"
          assert_includes guardrails, "known losing path"
          refute_includes menu, "Starting a new SCREEN?", "the conditional trigger is retired"
          assert_includes menu, "start the page from\n`compose`'s block match"
        end
      end

      def test_family_reference_carries_the_component_contract
        with_registry do |registry|
          reference = skill(registry).files.fetch("references/data.md")

          assert_includes reference, "## badge (`poetry_badge`)"
          assert_includes reference, "one of default|success"
          assert_includes reference, "- RULE: Status badges on one surface read as a SET."
        end
      end

      def test_blocks_reference_inlines_source_without_the_metadata_header
        with_registry do |registry|
          reference = skill(registry).files.fetch("references/blocks.md")

          assert_includes reference, "## Block: Data index (`data-index`)"
          assert_includes reference, %(<%= poetry_badge { "Fulfilled" } %>)
          refute_includes reference, "poetry:block title="
          assert_includes reference, "DEFAULT starting point"
          assert_includes reference, "`compose` tool routes a brief"
        end
      end

      def test_charts_reference_appears_only_with_a_charts_registry
        with_registry do |registry|
          charts = FakeRegistry.new(entries: { "poetry/charts/area_chart" => BADGE_ENTRY },
                                    blocks: nil, source_root: Pathname("."))
          files = skill(registry, charts_registry: charts).files

          assert_includes files.fetch("references/charts.md"), "## area_chart (`poetry_area_chart`)"
          assert_includes files.fetch("SKILL.md"), "1 chart components"
          refute_includes skill(registry).files.keys, "references/charts.md"
        end
      end
    end
  end
end
