# frozen_string_literal: true

require "rails/generators"
require_relative "../skills_section"

module Poetry
  # `rails g poetry:skill` (Skills v1) - installs or refreshes
  # poetry's two Claude Code skills in the app's .claude/skills/:
  #
  #   poetry/        the component-usage skill, GENERATED from the live
  #                  registry (SKILL.md menu + per-family references) -
  #                  re-run this generator after updating poetry gems
  #   poetry-design/ the taste layer (theme / compose / audit / study),
  #                  curated prose riding the DESIGN.md + design-lint rails
  #
  # poetry:install runs the same step; this standalone exists as the
  # refresh path (and for hosts that installed before Skills v1).
  class SkillGenerator < Rails::Generators::Base
    include Generators::SkillsSection

    desc "Install the poetry Claude Code skills (component usage + design taste) into .claude/skills/"

    def install_skills
      apply_poetry_skills
    end
  end
end
