# frozen_string_literal: true

require_relative "lib/poetry/agent/version"

Gem::Specification.new do |spec|
  spec.name = "poetry-agent"
  spec.version = Poetry::Agent::VERSION
  spec.authors = ["Matt Solt"]
  spec.email = ["mattsolt@gmail.com"]

  spec.summary = "Poetry's agent surfaces: MCP server, WebMCP runtime, AG-UI relay, and A2UI catalog and renderer."
  spec.description = "The agent-interop gem of Poetry, the AI-native UI component library. Five surfaces: " \
                     "the boot-free poetry-agent MCP server (the component contract over Model Context " \
                     "Protocol, with runtime skill delivery); the WebMCP runtime that registers rendered " \
                     "components' declared tools with in-browser agents (document.modelContext) behind " \
                     "safe-by-default, opt-in registration, declarative forms, and an origin-trial " \
                     "middleware; the AG-UI relay, a Rails client of the Agent-User Interaction protocol " \
                     "that runs an agent and relays its events as Turbo Streams, with frontend tools and " \
                     "interrupts; the A2UI catalog projected from the component registry; and the A2UI " \
                     "renderer that folds the envelope into server-rendered surfaces with forms, checks, " \
                     "functions, and morphing updates."
  spec.homepage = "https://poetryui.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"
  spec.metadata["homepage_uri"] = "https://poetryui.com"
  spec.metadata["documentation_uri"] = "https://poetryui.com/docs"
  spec.metadata["source_code_uri"] = "https://github.com/roboruby/poetry-agent"
  spec.metadata["changelog_uri"] = "https://github.com/roboruby/poetry-agent/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/roboruby/poetry-agent/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  # Dev-only surfaces never ship: the test/dummy host, scripts, rake tasks,
  # internal docs and design exports, the fidelity ledgers' snapshots, and
  # editor/tooling files.
  dev_only_dirs = %w[bin/ test/ docs/ script/ rakelib/ eval/ yard/ tmp/ .github/ .ruby-lsp/ .yardoc/
                     config/theme_fidelity/ config/dictionary_fidelity/ config/upstream_
                     config/hook_coverage config/theme_states]
  dev_only_files = %w[Gemfile Gemfile.lock Rakefile AGENTS.md .gitignore .rubocop.yml .yardopts .yard_coverage
                      .herb.yml package.json package-lock.json vitest.config.js]
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) || f.start_with?(*dev_only_dirs) || dev_only_files.include?(File.basename(f))
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "poetry-core", "= #{Poetry::Agent::VERSION}"
end
