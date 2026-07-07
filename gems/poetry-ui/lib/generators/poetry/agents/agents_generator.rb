# frozen_string_literal: true

require "rails/generators"
require_relative "../agents_section"

module Poetry
  # `rails g poetry:agents` - writes or refreshes the poetry section of the
  # host's AGENTS.md (the agent-facing pointer to llms.txt / poetry check)
  # without running the full install. poetry:install performs the same step.
  class AgentsGenerator < Rails::Generators::Base
    include Generators::AgentsSection

    desc "Write or refresh the poetry section of AGENTS.md (pointer to llms.txt + poetry check)"

    def write_agents_md
      apply_agents_section
    end
  end
end
