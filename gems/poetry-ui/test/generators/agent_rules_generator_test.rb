# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/poetry/agent_rules/agent_rules_generator"

module Poetry
  class AgentRulesGeneratorTest < Rails::Generators::TestCase
    tests Poetry::AgentRulesGenerator
    destination File.expand_path("../../tmp/generator-dest", __dir__)
    setup :prepare_destination

    def test_seeds_the_two_file_ruleset_and_imports
      run_generator

      assert_file ".poetry/agent-rules.md" do |content|
        assert_includes content, "DO NOT EDIT"
        assert_includes content, "RULE: Use poetry_button"
      end
      assert_file ".poetry/house-rules.md" do |content|
        assert_includes content, "This file is yours"
      end
      assert_file "CLAUDE.md" do |content|
        assert_includes content, Poetry::AgentRulesGenerator::START_MARKER
      end
      assert_file "AGENTS.md"
    end

    def test_rerun_refreshes_gem_rules_but_never_touches_house_rules
      run_generator
      house = File.join(destination_root, ".poetry/house-rules.md")
      File.write(house, "# my edits\n")
      rules = File.join(destination_root, ".poetry/agent-rules.md")
      File.write(rules, "stale\n")

      run_generator

      assert_equal "# my edits\n", File.read(house), "house rules are user-owned"
      assert_includes File.read(rules), "RULE:", "agent rules are gem-owned and force-refreshed"
    end

    def test_marker_import_preserves_host_content_and_is_idempotent
      claude = File.join(destination_root, "CLAUDE.md")
      File.write(claude, "# My project\n\nHost instructions stay.\n")

      run_generator
      first = File.read(claude)
      run_generator
      second = File.read(claude)

      assert_includes second, "Host instructions stay."
      assert_equal first, second, "re-running must not duplicate the import block"
      assert_equal 1, second.scan(Poetry::AgentRulesGenerator::START_MARKER).size
    end

    def test_broken_half_marker_is_detected_never_rewritten
      claude = File.join(destination_root, "CLAUDE.md")
      broken = "# My project\n#{Poetry::AgentRulesGenerator::START_MARKER}\nhand-edited, no end marker\n"
      File.write(claude, broken)

      run_generator

      assert_equal broken, File.read(claude), "a broken marker pair is surfaced, not guessed at"
    end
  end
end
