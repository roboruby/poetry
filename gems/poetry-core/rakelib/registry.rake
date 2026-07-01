# frozen_string_literal: true

namespace :registry do
  desc "Regenerate config/component_registry.yml from source (prop_definitions + Style dictionaries)"
  task :generate do
    poetry_css_boot!
    path = Poetry::Core::Registry.new.generate!
    puts "regenerated #{path}"
  end

  desc "Fail if the committed component registry does not match a fresh build (the CI drift gate)"
  task :verify do
    poetry_css_boot!
    if Poetry::Core::Registry.new.verified?
      puts "component registry in sync (#{Poetry::Core::Registry::RELATIVE_PATH})"
    else
      abort "stale component registry - run `bin/rake registry:generate` and commit"
    end
  end
end
