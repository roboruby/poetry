# frozen_string_literal: true

# Boots the dummy host (Rails before the poetry gems - see poetry-core's
# rakelib) so the components are loadable, then eager-loads everything.
def poetry_ui_boot!
  ENV["RAILS_ENV"] ||= "test"
  ENV["COVERAGE"] ||= "0"
  require_relative "../test/dummy/config/environment"
  Rails.application.eager_load!
end

def poetry_ui_registry
  Poetry::Core::Registry.new(source_root: Poetry::Ui.root)
end

namespace :registry do
  desc "Regenerate config/component_registry.yml from source"
  task :generate do
    poetry_ui_boot!
    puts "regenerated #{poetry_ui_registry.generate!}"
  end

  desc "Fail if the committed component registry does not match a fresh build (the CI drift gate)"
  task :verify do
    poetry_ui_boot!
    if poetry_ui_registry.verified?
      puts "component registry in sync (#{Poetry::Core::Registry::RELATIVE_PATH})"
    else
      abort "stale component registry - run `bin/rake registry:generate` and commit"
    end
  end
end
