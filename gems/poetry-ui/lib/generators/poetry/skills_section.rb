# frozen_string_literal: true

module Poetry
  module Generators
    # The two Claude Code skills (Skills v1), shared by
    # poetry:install and the standalone poetry:skill (the refresh path -
    # re-run after updating poetry gems):
    #
    #   .claude/skills/poetry/        GENERATED from the live registry
    #   .claude/skills/poetry-design/ curated taste layer (static templates)
    #
    # Same Thor note as AgentsSection: only methods on the generator class
    # register as steps, so each generator declares its own public step and
    # calls apply_poetry_skills.
    module SkillsSection
      DESIGN_TEMPLATES = File.expand_path("skill/templates/poetry-design", __dir__)

      def apply_poetry_skills
        Poetry::Ui.skill_files.each do |relative, content|
          create_file ".claude/skills/poetry/#{relative}", content
        end
        design_skill_files.each do |relative, content|
          create_file ".claude/skills/poetry-design/#{relative}", content
        end
      end

      # Path => content for the curated skill - the eval harness writes
      # these without a Thor context (the agents_section_text pattern:
      # Object.new.extend(SkillsSection).design_skill_files).
      def design_skill_files
        root = Pathname(DESIGN_TEMPLATES)
        Dir.glob(root.join("**/*.md").to_s).to_h do |file|
          [Pathname(file).relative_path_from(root).to_s, File.read(file)]
        end
      end
    end
  end
end
