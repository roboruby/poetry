# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "rails/generators/test_case"
require "generators/poetry/agents/agents_generator"

module Poetry
  class AgentsGeneratorTest < Rails::Generators::TestCase
    tests Poetry::AgentsGenerator
    destination File.expand_path("../tmp/agents-dest", __dir__)
    setup :prepare_destination

    SECTION_SPAN = /#{Regexp.escape(Generators::AgentsSection::BEGIN_MARKER)}.*
                    #{Regexp.escape(Generators::AgentsSection::END_MARKER)}/mx

    def test_creates_agents_md_when_absent
      run_generator

      assert_file "AGENTS.md" do |content|
        assert_match(/\A#{Regexp.escape(Generators::AgentsSection::BEGIN_MARKER)}/o, content)
        assert_match(/Building UI with poetry \(\d+ components/, content, "count derives from the registry")
        assert_operator content[/\((\d+) components/, 1].to_i, :>, 10,
                        "count reads the components map, not the YAML root"
        assert_match %r{/poetry/llms-full\.txt}, content
        assert_match(/poetry:check/, content)
        assert_match(/poetry-agent/, content, "the MCP server is part of the documented workflow")
        assert_match(/poetry:design:export/, content, "the DESIGN.md interop surface is part of the front door")
        assert_match(/poetry:block/, content, "blocks are part of the documented workflow")
        assert_match(/describe_block/, content, "the boot-free block path is named")
        assert_match(/\+ \d+ blocks\)/, content, "the block count derives from the registry")
      end
    end

    def test_appends_section_to_an_existing_agents_md_without_markers
      hand_written = "# Agents\n\nHouse rules the host wrote.\n"
      FileUtils.mkdir_p(destination_root)
      File.write(File.join(destination_root, "AGENTS.md"), hand_written)

      run_generator

      assert_file "AGENTS.md" do |content|
        assert content.start_with?(hand_written), "host content stays first, untouched"
        assert_match(/Building UI with poetry/, content)
      end
    end

    def test_refreshes_only_the_marked_section_on_rerun
      FileUtils.mkdir_p(destination_root)
      File.write(File.join(destination_root, "AGENTS.md"), <<~MD)
        # Agents

        Above the section.

        #{Generators::AgentsSection::BEGIN_MARKER}
        stale poetry content from an older version
        #{Generators::AgentsSection::END_MARKER}

        Below the section.
      MD

      run_generator

      assert_file "AGENTS.md" do |content|
        assert_match(/Above the section\./, content)
        assert_match(/Below the section\./, content)
        assert_no_match(/stale poetry content/, content)
        assert_match(/Building UI with poetry/, content)
        assert_equal 1, content.scan(Generators::AgentsSection::BEGIN_MARKER).size
      end
    end

    def test_rerun_is_idempotent
      run_generator
      first = File.read(File.join(destination_root, "AGENTS.md"))

      run_generator
      second = File.read(File.join(destination_root, "AGENTS.md"))

      assert_equal first, second
      assert_equal 1, second.scan(SECTION_SPAN).size
    end
  end
end
