# frozen_string_literal: true

require "test_helper"
require "rake"

module Poetry
  module Ui
    # The doc-prose tier (an external review's docPropReferences insight, ported):
    # curated prose is LLM steering text - a backticked helper, path, rake
    # task, design-lint rule, token, or count that doesn't exist steers
    # agents toward hallucinated APIs. Scope is the HAND-CURATED surfaces
    # only - the poetry-design skill templates and AGENTS.md; the usage
    # skill and registry projections are generated from source and cannot
    # drift. Every check resolves against the machine (helpers module,
    # filesystem, rake inventory, DesignLint::RULES, the token CSS, the
    # registry), never against a hand-maintained allowlist of names.
    class DocProseTest < Minitest::Test
      SKILL_DIR = Poetry::Ui.root.join("lib/generators/poetry/skill/templates/poetry-design")
      AGENTS_MD = Poetry::Ui.root.join("AGENTS.md")

      # Gem-repo path roots assertable from this repo. app/-rooted tokens
      # are HOST-app paths (the install generator creates them) - real, but
      # not this filesystem's to verify.
      REPO_PATH_ROOTS = %w[references themes docs eval script lib test config].freeze

      BareToken = Struct.new(:file, :line, :text)

      NUMBER_WORDS = %w[zero one two three four five six seven eight nine ten eleven twelve
                        thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty].freeze

      def test_backticked_poetry_helpers_exist
        helpers = ComponentsHelper.public_instance_methods(false).grep(/\Apoetry_/).map(&:to_s)
        offenses = tokens.filter_map do |token|
          next unless token.text.match?(/\Apoetry_[a-z0-9_]+[(\s]?/)

          name = token.text[/\Apoetry_[a-z0-9_]+/]
          next if helpers.include?(name)

          "#{token.file}:#{token.line} references `#{name}` - no such helper"
        end

        assert_empty offenses, offenses.join("\n")
      end

      def test_backticked_repo_paths_resolve
        offenses = tokens.filter_map do |token|
          text = token.text
          next if text.include?(" ") || text.include?("<") || !text.include?("/")
          next unless REPO_PATH_ROOTS.include?(text.split("/").first)
          next if resolvable_path?(text)

          scope = text.start_with?("references/") ? "the skill dirs" : "the gem root"

          "#{token.file}:#{token.line} references `#{text}` - no such file (checked #{scope})"
        end

        assert_empty offenses, offenses.join("\n")
      end

      def test_backticked_rake_tasks_exist
        offenses = tokens.filter_map do |token|
          kind, name = command_reference(token.text)
          next if kind.nil?

          if kind == :generator
            next if Poetry::Ui.root.join("lib/generators", name.tr(":", "/")).directory?

            next "#{token.file}:#{token.line} references generator `#{name}` - no such generator"
          end

          next if task_known?(name)

          "#{token.file}:#{token.line} references task `#{name}` - not in the rake inventory"
        end

        assert_empty offenses, offenses.join("\n")
      end

      def test_the_audit_rules_list_matches_design_lint_exactly
        documented = audit_rule_slugs
        actual = Poetry::Core::DesignLint::RULES.keys

        assert_equal actual.sort, documented.sort,
                     "audit.md's rules list must mirror DesignLint::RULES both ways - " \
                     "a new rule ships WITH its skill prose, a renamed rule takes its prose along"
      end

      def test_component_count_claims_match_the_registry
        count = Poetry::Core::Registry.new(source_root: Poetry::Ui.root).components.size
        offenses = prose_files.flat_map do |file|
          file.read.each_line.with_index(1).filter_map do |line, number|
            claim = line[/(\d+)-component/, 1]
            next if claim.nil? || Integer(claim) == count

            "#{file.basename}:#{number} claims #{claim} components - the registry has #{count}"
          end
        end

        assert_empty offenses, offenses.join("\n")
      end

      def test_rule_count_words_match_design_lint
        expected = Poetry::Core::DesignLint::RULES.size
        offenses = prose_files.flat_map do |file|
          file.read.each_line.with_index(1).filter_map do |line, number|
            word = line[/[Tt]he (\w+) (?:design-slop )?rules/, 1]
            next if word.nil?

            claimed = NUMBER_WORDS.index(word.downcase) || word[/\A\d+\z/]&.to_i
            next if claimed.nil? # "The design-lint rules" heading etc.
            next if claimed == expected

            "#{file.basename}:#{number} claims #{claimed} rules - DesignLint has #{expected}"
          end
        end

        assert_empty offenses, offenses.join("\n")
      end

      def test_backticked_css_tokens_are_defined
        offenses = tokens.filter_map do |token|
          next unless token.text.match?(/\A--[a-z][a-z0-9-]*\z/)
          next if defined_css_tokens.include?(token.text)

          "#{token.file}:#{token.line} references `#{token.text}` - not defined in tokens/ or themes/"
        end

        assert_empty offenses, offenses.join("\n")
      end

      private

      def prose_files
        [AGENTS_MD, *Dir.glob("#{SKILL_DIR}/**/*.md").map { |file| Pathname.new(file) }]
      end

      def tokens
        @tokens ||= prose_files.flat_map do |file|
          file.read.each_line.with_index(1).flat_map do |line, number|
            line.scan(/`([^`]+)`/).map { |(text)| BareToken.new(file.basename.to_s, number, text) }
          end
        end
      end

      def resolvable_path?(text)
        root = text.start_with?("references/") ? SKILL_DIR : Poetry::Ui.root
        candidate = root.join(text.delete_suffix("/"))
        return true if candidate.exist?
        return true if text.include?("*") && !Dir.glob(candidate.to_s).empty?

        # Cross-skill mentions: the usage skill's generated reference files
        # (SkillText emits them) are legitimate vocabulary here.
        text.start_with?("references/") && generated_usage_references.include?(text)
      end

      def generated_usage_references
        @generated_usage_references ||=
          Poetry::Core.root.join("lib/poetry/core/skill_text.rb").read.scan(%r{references/[a-z_]+\.md}).to_set
      end

      # `bundle exec rake x`, `bin/rails x`, `rake x`, env-prefixed forms,
      # and bare task-shaped tokens (`eval:capture`); nil for everything
      # else. Wildcards survive (prefix-matched against the inventory).
      def command_reference(raw)
        words = raw.gsub(/"([^"]*)"|'([^']*)'/) { Regexp.last_match(1) || Regexp.last_match(2) }.split(/\s+/)
        words.shift while words.first&.match?(/\A[A-Z][A-Z0-9_]*=\S*\z/)
        words.shift(2) if words[0] == "bundle" && words[1] == "exec"

        if %w[rake rails bin/rails].include?(words[0])
          runner = words.shift
          return [:generator, words[1]] if runner != "rake" && %w[g generate].include?(words[0]) && words[1]

          candidate = words[0]
        elsif words.length == 1
          candidate = words[0]
        end

        return nil unless candidate&.match?(/\A[a-z][a-z0-9_]*(:[a-z0-9_*]+)+(\[[^\]]*\])?\z/)

        [:task, candidate.sub(/\[[^\]]*\]\z/, "")]
      end

      def task_known?(name)
        if name.include?("*")
          prefix = name.delete_suffix("*")
          rake_inventory.any? { |task| task.start_with?(prefix) }
        else
          rake_inventory.include?(name)
        end
      end

      # The gem root's own rake surface (subprocess - the Rakefile is not
      # test-process-loadable) plus the ENGINE tasks hosts run through
      # bin/rails (lib/tasks/**/*.rake, loaded into an isolated Rake app).
      def rake_inventory
        @rake_inventory ||= begin
          root_tasks = Dir.chdir(Poetry::Ui.root) { `bundle exec rake -AT 2>/dev/null` }
                          .lines.filter_map { |line| line.split(/\s+/)[1]&.sub(/\[[^\]]*\]\z/, "") }
          raise "rake -AT produced no tasks - inventory unavailable" if root_tasks.empty?

          (root_tasks + engine_tasks).to_set
        end
      end

      def engine_tasks
        application = Rake::Application.new
        previous = Rake.application
        Rake.application = application
        Dir.glob(Poetry::Ui.root.join("lib/tasks/**/*.rake")).each { |file| load file }
        application.tasks.map { |task| task.name.sub(/\[[^\]]*\]\z/, "") }
      ensure
        Rake.application = previous
      end

      def audit_rule_slugs
        section = SKILL_DIR.join("references/audit.md").read[/^## The design-lint rules.*?(?=^## |\z)/m]

        refute_nil section, "audit.md must keep its '## The design-lint rules' section"

        section.scan(/^- `([a-z][a-z0-9-]*)`/).flatten
      end

      def defined_css_tokens
        @defined_css_tokens ||= [
          *Dir.glob(Poetry::Core.root.join("tokens/*.css")),
          *Dir.glob(Poetry::Ui.root.join("themes/*.css"))
        ].flat_map { |file| File.read(file).scan(/(--[a-z][a-z0-9-]*)\s*:/).flatten }.to_set
      end
    end
  end
end
