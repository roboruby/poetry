# frozen_string_literal: true

require "rails/generators"
require_relative "../skills_section"

module Poetry
  # `rails g poetry:skill` - installs or refreshes poetry's Claude Code
  # skills in the app's .claude/skills/:
  #
  #   poetry/           the component-usage skill, GENERATED from the live
  #                     registry (SKILL.md menu + per-family references) -
  #                     re-run this generator after updating poetry gems
  #   poetry-design/    the taste layer (theme / compose / audit / study),
  #                     curated prose riding the DESIGN.md + design-lint rails
  #   poetry-component/ the authoring layer (anatomy / documentation /
  #                     audit) for components the app builds itself
  #
  # poetry:install runs the same step; this standalone exists as the
  # refresh path (and for hosts that installed before the skills shipped).
  #
  # @example
  #   bin/rails g poetry:skill
  class SkillGenerator < Rails::Generators::Base
    include Generators::SkillsSection

    desc "Install the poetry Claude Code skills (usage + design + authoring) into .claude/skills/"

    # Step: applies the three skill directories.
    # @api private
    def install_skills
      apply_poetry_skills
    end
  end
end
