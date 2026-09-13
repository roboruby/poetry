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
      SKILLS_DIR = ".claude/skills"
      DESIGN_TEMPLATES = File.expand_path("skill/templates/poetry-design", __dir__)
      COMPONENT_TEMPLATES = File.expand_path("skill/templates/poetry-component", __dir__)

      # Writes or refreshes the three skill directories under
      # .claude/skills/, and says so when the host ignores that directory:
      # the files still serve this checkout, but the committed AGENTS.md
      # points every agent at them, so a teammate's or CI's clone needs
      # the refresh command (or the directory un-ignored).
      def apply_poetry_skills
        # Generated artifacts, refreshed like the vendored CSS: no overwrite
        # prompt (an upgrade re-run asked four questions, and a piped stdin
        # answered yes). `--skip` keeps a file that exists, for a host that
        # hand-edited one - a config force would beat that flag, so it is
        # passed only when --skip was not.
        force = !options[:skip]
        Poetry::Ui.skill_files(host_registry: Poetry::Ui.host_registry).each do |relative, content|
          create_file ".claude/skills/poetry/#{relative}", content, force: force
        end
        design_skill_files.each do |relative, content|
          create_file ".claude/skills/poetry-design/#{relative}", content, force: force
        end
        component_skill_files.each do |relative, content|
          create_file ".claude/skills/poetry-component/#{relative}", content, force: force
        end
        announce_ignored_skills if skills_ignored?
      end

      # @api private
      def announce_ignored_skills
        say_status :note, "#{SKILLS_DIR} is gitignored here, so the skills stay local to this checkout - " \
                          "teammates and CI get them with `bin/rails g poetry:skill`, or un-ignore the directory",
                   :cyan
      end

      # Whether git ignores the skills directory in the destination: true
      # only on an ignored answer (exit 0). No git on the PATH (system
      # returns nil), no repository (128), or not ignored (1) all read as
      # "nothing to say" - the write itself never depends on git.
      # @api private
      def skills_ignored?
        system("git", "-C", destination_root.to_s, "check-ignore", "-q", SKILLS_DIR,
               out: File::NULL, err: File::NULL) == true
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
