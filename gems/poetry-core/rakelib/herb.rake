# frozen_string_literal: true

# The Herb compile gate: the parse gate (css:herb) proves every template
# has a well-formed HTML+ERB tree; this one proves every template also
# COMPILES under Herb::Engine, the compiler Rails uses for hosts that opt
# into the Herb ERB implementation. Its validators reject shapes the parser
# accepts, so both gates run in the default suite.
namespace :herb do
  desc "Herb compile gate: fail if any template refuses to compile under Herb::Engine"
  task :compile do
    poetry_css_boot!
    result = Poetry::Core::TemplateCompile.check(root: Poetry::Core.root)
    abort "herb compile errors:\n#{result.errors.join("\n")}" unless result.errors.empty?

    puts "herb: all #{result.compiled} templates compile under Herb::Engine"
  end
end
