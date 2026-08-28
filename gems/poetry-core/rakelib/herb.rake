# frozen_string_literal: true

# The Herb gates. The parse gate (css:herb / the template-class scan) proves
# every template has a well-formed HTML+ERB tree; herb:compile proves it
# also COMPILES under Herb::Engine, the compiler Rails uses for hosts that
# opt into the Herb ERB implementation (its validators reject shapes the
# parser accepts, so it runs in the default suite); herb:lint runs the
# @herb-tools linter (Node) over the templates, configured by .herb.yml (rules pinned
# to a linter version, house-idiom rules disabled with their reasons) -
# kept out of `default` because it needs Node; CI runs it in its own job.
namespace :herb do
  desc "Herb compile gate: fail if any template refuses to compile under Herb::Engine"
  task :compile do
    poetry_css_boot!
    result = Poetry::Core::TemplateCompile.check(root: Poetry::Core.root)
    abort "herb compile errors:\n#{result.errors.join("\n")}" unless result.errors.empty?

    puts "herb: all #{result.compiled} templates compile under Herb::Engine"
  end

  desc "Herb lint gate: run @herb-tools/linter over the templates (.herb.yml decides the rules)"
  task :lint do
    version = File.read(".herb.yml")[/^version:\s*(\S+)/, 1] || "latest"
    abort "herb:lint needs Node (npx) on PATH" unless system("npx --version > /dev/null 2>&1")

    sh "npx --yes @herb-tools/linter@#{version} app"
  end
end
