# frozen_string_literal: true

# The agent-surface registry (the poetry-charts pattern): the effects'
# options, slots, parts, wiring and behaviors introspected from source into
# config/component_registry.yml, drift-gated - the file poetry check,
# llms.txt and the docs read.

def poetry_motion_boot!
  ENV["RAILS_ENV"] ||= "test"
  ENV["COVERAGE"] ||= "0"
  require_relative "../test/dummy/config/environment"
  Rails.application.eager_load!
end

namespace :registry do
  desc "Regenerate config/component_registry.yml from source"
  task :generate do
    poetry_motion_boot!
    puts "regenerated #{Poetry::Motion.registry.generate!}"
  end

  desc "Fail if the committed component registry does not match a fresh build (the CI drift gate)"
  task :verify do
    poetry_motion_boot!
    if Poetry::Motion.registry.verified?
      puts "component registry in sync (#{Poetry::Core::Registry::RELATIVE_PATH})"
    else
      abort "stale component registry - run `bin/rake registry:generate` and commit"
    end
  end
end
