# frozen_string_literal: true

require_relative "lib/poetry/lucide/version"

Gem::Specification.new do |spec|
  spec.name = "poetry-lucide"
  spec.version = Poetry::Lucide::VERSION
  spec.authors = ["Matt Solt"]
  spec.email = ["mattsolt@gmail.com"]

  spec.summary = "Lucide icons for Poetry, vendored and sanitized at a pinned upstream commit."
  spec.description = "The default Poetry icon set: Lucide's icons vendored at a pinned commit SHA, sanitized at " \
                     "vendor time, registered with poetry-core's icon registry."
  spec.homepage = "https://poetryui.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"
  spec.metadata["homepage_uri"] = "https://poetryui.com"
  spec.metadata["documentation_uri"] = "https://poetryui.com/docs"
  spec.metadata["source_code_uri"] = "https://github.com/roboruby/poetry-lucide"
  spec.metadata["changelog_uri"] = "https://github.com/roboruby/poetry-lucide/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/roboruby/poetry-lucide/issues"
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
  spec.require_paths = ["lib"]

  spec.add_dependency "poetry-core", "= #{Poetry::Lucide::VERSION}"
end
