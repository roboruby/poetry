# frozen_string_literal: true

# The agent-surface registry (the poetry-motion pattern): the island's
# options, parts and wiring introspected from source into
# config/component_registry.yml, drift-gated - the file poetry check,
# llms.txt and the docs read.

def poetry_island_boot!
  ENV["RAILS_ENV"] ||= "test"
  ENV["COVERAGE"] ||= "0"
  require_relative "../test/dummy/config/environment"
  Rails.application.eager_load!
end

namespace :registry do
  desc "Regenerate config/component_registry.yml from source"
  task :generate do
    poetry_island_boot!
    puts "regenerated #{Poetry::Island.registry.generate!}"
  end

  desc "Fail if the committed component registry does not match a fresh build (the CI drift gate)"
  task :verify do
    poetry_island_boot!
    if Poetry::Island.registry.verified?
      puts "component registry in sync (#{Poetry::Core::Registry::RELATIVE_PATH})"
    else
      abort "stale component registry - run `bin/rake registry:generate` and commit"
    end
  end
end
