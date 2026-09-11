# frozen_string_literal: true

# The app's committed component registry: the app's own components
# (`helper :name` on the DSL) written to config/component_registry.yml -
# the same path a gem's registry lives at - so boot-free consumers (the
# MCP server, the runtime skill) find the app's components the way they
# find a gem's, contracts and agent rules included. Opt-in: the booted
# surfaces (poetry:check, llms.txt, poetry:skill) read the live classes
# and never need this file. Once written it is a build artifact:
# `poetry:check` warns when it is stale and `poetry:verify` fails.
# Loaded automatically by the engine (lib/tasks).
namespace :poetry do
  desc "Write config/component_registry.yml from the app's own components (the MCP server reads it; commit it)"
  task registry: :environment do
    registry = Poetry::Core::HostComponents.registry(root: Rails.root)
    path = registry.generate!
    count = registry.entries.size
    noun = count == 1 ? "app component" : "app components"
    puts "poetry:registry: wrote #{path.relative_path_from(Rails.root)} (#{count} #{noun}) - commit it; " \
         "re-run after changing app components (poetry:verify fails when stale)"
  end
end
