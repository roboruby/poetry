# frozen_string_literal: true

module Poetry
  module Generators
    # The Claude Code skills, shared by poetry:install and the standalone
    # poetry:skill (the refresh path - re-run after updating poetry gems):
    #
    #   .claude/skills/poetry/           GENERATED from the live registry
    #   .claude/skills/poetry-design/    curated taste layer (static templates)
    #   .claude/skills/poetry-component/ authoring layer: anatomy, docs
    #                                    standard, audit checklist (static)
    #
    # Same Thor note as AgentsSection: only methods on the generator class
    # register as steps, so each generator declares its own public step and
    # calls apply_poetry_skills.
    #
    # @api private
    module SkillsSection
      DESIGN_TEMPLATES = File.expand_path("skill/templates/poetry-design", __dir__)
      COMPONENT_TEMPLATES = File.expand_path("skill/templates/poetry-component", __dir__)

      # Writes or refreshes the three skill directories under
      # .claude/skills/.
      def apply_poetry_skills
        Poetry::Ui.skill_files.each do |relative, content|
          create_file ".claude/skills/poetry/#{relative}", content
        end
        design_skill_files.each do |relative, content|
          create_file ".claude/skills/poetry-design/#{relative}", content
        end
        component_skill_files.each do |relative, content|
          create_file ".claude/skills/poetry-component/#{relative}", content
        end
      end

      # Path => content for the curated skills - the eval harness writes
      # these without a Thor context (the agents_section_text pattern:
      # Object.new.extend(SkillsSection).design_skill_files).
      def design_skill_files
        static_skill_files(DESIGN_TEMPLATES)
      end

      # Path => content for the poetry-component authoring skill (static
      # templates).
      def component_skill_files
        static_skill_files(COMPONENT_TEMPLATES)
      end

      # Path => content for every .md under a template root.
      def static_skill_files(templates)
        root = Pathname(templates)
        Dir.glob(root.join("**/*.md").to_s).to_h do |file|
          [Pathname(file).relative_path_from(root).to_s, File.read(file)]
        end
      end
    end
  end
end
