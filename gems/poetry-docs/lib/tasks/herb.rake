# frozen_string_literal: true

# The Herb LINT gate for the docs site: the @herb-tools linter (Node) over
# every template, configured by .herb.yml (rules pinned to a linter
# version, the docs-specific carve-outs documented in place). Compile
# under Herb::Engine is HerbCompileTest; this is the style/a11y tier.
namespace :herb do
  desc "Herb lint gate: run @herb-tools/linter over app/ (.herb.yml decides the rules)"
  task :lint do
    version = File.read(".herb.yml")[/^version:\s*(\S+)/, 1] || "latest"
    abort "herb:lint needs Node (npx) on PATH" unless system("npx --version > /dev/null 2>&1")

    sh "npx --yes @herb-tools/linter@#{version} app"
  end
end
