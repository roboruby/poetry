# frozen_string_literal: true

# The agent-surface registry (the poetry-ui / pattern): the chart
# components' options/slots/elements/controllers introspected from source
# into config/component_registry.yml, drift-gated in CI - the same file
# poetry check / llms.txt / poetry-agent project from.

def poetry_charts_registry
  Poetry::Charts.registry
end

namespace :registry do
  desc "Regenerate config/component_registry.yml from source"
  task :generate do
    poetry_charts_boot!
    puts "regenerated #{poetry_charts_registry.generate!}"
  end

  desc "Fail if the committed component registry does not match a fresh build (the CI drift gate)"
  task :verify do
    poetry_charts_boot!
    if poetry_charts_registry.verified?
      puts "component registry in sync (#{Poetry::Core::Registry::RELATIVE_PATH})"
    else
      abort "stale component registry - run `bin/rake registry:generate` and commit"
    end
  end
end
