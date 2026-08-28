# frozen_string_literal: true

# The Herb compile gate (see poetry-core's rakelib/herb.rake): every
# component template AND every block/scaffold template poetry copies into
# hosts must compile under Herb::Engine, the compiler Rails uses for hosts
# on the Herb ERB implementation.
namespace :herb do
  desc "Herb compile gate: fail if any component or generator template refuses to compile under Herb::Engine"
  task :compile do
    poetry_ui_boot!
    result = Poetry::Core::TemplateCompile.check(root: Poetry::Ui.root)
    abort "herb compile errors:\n#{result.errors.join("\n")}" unless result.errors.empty?

    puts "herb: all #{result.compiled} templates compile under Herb::Engine"
  end
end
