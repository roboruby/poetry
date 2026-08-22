# frozen_string_literal: true

module Poetry
  module Ui
    # The recipes channel (Recipes Channel v1): multi-file payloads served
    # through the registry beside components and blocks. Every definition's
    # files are LAZY callables over gem-shipped sources - the same files
    # the generators install - so the projection cannot drift from the
    # generator path. Names share the flat kebab namespace (RegistryIndex
    # collision-checks recipes against components and blocks at first
    # touch).
    module Recipes
      SCAFFOLD_TEMPLATES = "lib/generators/poetry/scaffold_templates/templates"
      SCREEN_SOURCES = "lib/generators/poetry/recipes"

      class << self
        def definitions
          [agent_embed, skill_poetry, skill_poetry_design, scaffold_templates,
           screen(
             "screen-data-index", title: "Data index screen",
                                  description: "The data-index block as a working feature slice: OrdersController, " \
                                               "its index view rendering the block, and a system test. Add " \
                                               "`resources :orders, only: :index` to routes.",
                                  dependencies: ["data-index"]
           ),
           screen(
             "screen-settings", title: "Settings screen",
                                description: "A settings page composed from the page-header, section-card, and " \
                                             "destructive-panel blocks: SettingsController, the composed view, " \
                                             "and a system test. Add `resource :settings, only: :show` to routes.",
                                dependencies: %w[page-header section-card destructive-panel]
           )]
        end

        private

        def skill_poetry
          {
            "name" => "skill-poetry",
            "title" => "poetry skill bundle",
            "description" => "The component-usage Claude Code skill (SKILL.md + per-family " \
                             "references), generated from the live registry - the same files " \
                             "`bin/rails g poetry:skill` installs.",
            "files" => lambda {
              Poetry::Ui.runtime_skill_files.map do |rel, content|
                { "path" => rel, "target" => ".claude/skills/poetry/#{rel}", "content" => content }
              end
            }
          }
        end

        def skill_poetry_design
          {
            "name" => "skill-poetry-design",
            "title" => "poetry-design skill bundle",
            "description" => "The design-taste Claude Code skill (theme / compose / audit / study " \
                             "references) - the same files `bin/rails g poetry:skill` installs.",
            "files" => lambda {
              require "generators/poetry/skills_section"
              files = Object.new.extend(Poetry::Generators::SkillsSection).design_skill_files
              files.map do |rel, content|
                { "path" => rel, "target" => ".claude/skills/poetry-design/#{rel}", "content" => content }
              end
            }
          }
        end

        # The scaffold override set: static .tt files whose targets mirror
        # `poetry:scaffold_templates` exactly - Rails does the
        # parameterization later, so the payload needs none.
        def scaffold_templates
          {
            "name" => "scaffold-templates",
            "title" => "poetry scaffold templates",
            "description" => "The lib/templates override set that makes the STANDARD `rails g " \
                             "scaffold` emit poetry-composed views and a matching controller - " \
                             "the same files `bin/rails g poetry:scaffold_templates` copies.",
            "files" => lambda {
              base = Poetry::Ui.root.join(SCAFFOLD_TEMPLATES)
              base.glob("*.tt").sort.map do |file|
                name = file.basename.to_s
                target = if name == "controller.rb.tt"
                           "lib/templates/rails/scaffold_controller/controller.rb.tt"
                         else
                           "lib/templates/erb/scaffold/#{name}"
                         end
                { "path" => name, "target" => target, "content" => file.read }
              end
            }
          }
        end

        # The in-page GUI agent loader (operator-register findings pass,
        # 2026-08-22): the Turbo-hardened page-agent embed as a copy-in
        # Stimulus controller - CDN-pinned script, opt-in, BYO key, and
        # the poetry operator ground rules embedded as fallback
        # instructions.
        def agent_embed
          {
            "name" => "agent-embed",
            "title" => "In-page agent embed",
            "description" => "An opt-in page-agent loader for a poetry app as a Stimulus " \
                             "controller: pinned CDN script (?autoInit=false), session-only " \
                             "BYO key, Turbo-hardened (remounts on turbo:load, idle-only " \
                             "rebuild, module-init catch-up), poetry operator instructions " \
                             "built in. Wire a form with targets model/baseUrl/apiKey/status.",
            "files" => lambda {
              base = Poetry::Ui.root.join(SCREEN_SOURCES, "agent_embed")
              base.glob("**/*").select(&:file?).sort.map do |file|
                rel = file.relative_path_from(base).to_s
                { "path" => rel, "target" => rel, "content" => file.read }
              end
            }
          }
        end

        def screen(name, title:, description:, dependencies:)
          {
            "name" => name,
            "title" => title,
            "description" => description,
            "registry_dependencies" => dependencies,
            "files" => lambda {
              base = Poetry::Ui.root.join(SCREEN_SOURCES, name.tr("-", "_"))
              base.glob("**/*").select(&:file?).sort.map do |file|
                rel = file.relative_path_from(base).to_s
                { "path" => rel, "target" => rel, "content" => file.read }
              end
            }
          }
        end
      end
    end
  end
end
