# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "rails/generators/test_case"
require "generators/poetry/skill/skill_generator"

module Poetry
  class SkillGeneratorTest < Rails::Generators::TestCase
    tests Poetry::SkillGenerator
    destination File.expand_path("../tmp/skill-dest", __dir__)
    setup :prepare_destination

    # The destination sits inside the gem's own checkout, whose .gitignore
    # covers test/tmp - `git init` makes it a repository of its own, so
    # the answer is the destination's, not the gem's.
    def test_says_so_when_the_host_ignores_the_skills_directory
      system("git", "init", "-q", destination_root, out: File::NULL, err: File::NULL)
      File.write(File.join(destination_root, ".gitignore"), ".claude/\n")

      output = run_generator

      assert_match(/\.claude\/skills is gitignored here/, output)
      assert_match(%r{bin/rails g poetry:skill}, output)
      assert_file ".claude/skills/poetry/SKILL.md"
    end

    def test_stays_quiet_when_the_skills_directory_is_tracked
      system("git", "init", "-q", destination_root, out: File::NULL, err: File::NULL)
      File.write(File.join(destination_root, ".gitignore"), "/tmp/\n")

      output = run_generator

      refute_match(/gitignored/, output)
    end

    def test_installs_every_skill
      run_generator

      assert_file ".claude/skills/poetry/SKILL.md" do |content|
        assert_match(/^name: poetry$/, content)
        assert_match(%r{bin/rails g poetry:skill}, content, "the regeneration pointer ships")
      end
      assert_file ".claude/skills/poetry/references/forms.md"
      assert_file ".claude/skills/poetry-design/SKILL.md" do |content|
        assert_match(/^name: poetry-design$/, content)
      end
      assert_file ".claude/skills/poetry-design/references/theme.md"
      assert_file ".claude/skills/poetry-design/references/compose.md"
      assert_file ".claude/skills/poetry-design/references/audit.md"
      assert_file ".claude/skills/poetry-design/references/study.md"
      assert_file ".claude/skills/poetry-component/SKILL.md" do |content|
        assert_match(/^name: poetry-component$/, content)
      end
      assert_file ".claude/skills/poetry-component/references/anatomy.md"
      assert_file ".claude/skills/poetry-component/references/documentation.md"
      assert_file ".claude/skills/poetry-component/references/checklist.md"
    end

    def test_usage_skill_regenerates_from_the_live_registry
      run_generator

      assert_file ".claude/skills/poetry/references/data.md" do |content|
        assert_match(/## badge \(`poetry_badge`\)/, content)
        assert_match(/success/, content, "the registry's variant vocabulary ships")
      end
      assert_file ".claude/skills/poetry/references/blocks.md" do |content|
        Poetry::Ui.registry.blocks.each_key { |name| assert_match(/#{name}/, content) }
      end
    end
  end
end
