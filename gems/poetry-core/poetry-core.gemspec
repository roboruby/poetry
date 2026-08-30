# frozen_string_literal: true

require_relative "lib/poetry/core/version"

Gem::Specification.new do |spec|
  spec.name = "poetry-core"
  spec.version = Poetry::Core::VERSION
  spec.authors = ["Matt Solt"]
  spec.email = ["mattsolt@gmail.com"]

  spec.summary = "Rails engine and component DSL for Poetry, the AI-native UI component library."
  spec.description = "The Rails engine, component DSL, and primitives for Poetry, " \
                     "the AI-native UI component library."
  spec.homepage = "https://poetryui.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  # Require MFA for gem pushes (supply-chain protection).
  spec.metadata["homepage_uri"] = "https://poetryui.com"
  spec.metadata["documentation_uri"] = "https://poetryui.com/docs"
  spec.metadata["source_code_uri"] = "https://github.com/roboruby/poetry-core"
  spec.metadata["changelog_uri"] = "https://github.com/roboruby/poetry-core/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/roboruby/poetry-core/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Files shipped in the gem come from git; tooling/test/docs are excluded.
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

  spec.add_dependency "rails", "~> 8.0"
  spec.add_dependency "tailwind_merge", "~> 1.3"
  spec.add_dependency "view_component", "~> 4.0"
  spec.add_dependency "zeitwerk", "~> 2.6"
end
