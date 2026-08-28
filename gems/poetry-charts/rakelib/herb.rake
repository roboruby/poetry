# frozen_string_literal: true

# The Herb compile gate (see poetry-core's rakelib/herb.rake): every chart
# template must compile under Herb::Engine, the compiler Rails uses for
# hosts on the Herb ERB implementation.
namespace :herb do
  desc "Herb compile gate: fail if any chart template refuses to compile under Herb::Engine"
  task :compile do
    poetry_charts_boot!
    result = Poetry::Core::TemplateCompile.check(root: Poetry::Charts.root)
    abort "herb compile errors:\n#{result.errors.join("\n")}" unless result.errors.empty?

    puts "herb: all #{result.compiled} templates compile under Herb::Engine"
  end
end
