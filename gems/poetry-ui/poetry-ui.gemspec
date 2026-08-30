# frozen_string_literal: true

require_relative "lib/poetry/ui/version"

Gem::Specification.new do |spec|
  spec.name = "poetry-ui"
  spec.version = Poetry::Ui::VERSION
  spec.authors = ["Matt Solt"]
  spec.email = ["mattsolt@gmail.com"]

  spec.summary = "The poetry component library: shadcn-parity ViewComponents on poetry-core."
  spec.description = "poetry's components - accessible, themeable, agent-legible ViewComponents " \
                     "built entirely on poetry-core's public DSL."
  spec.homepage = "https://github.com/roboruby/poetry-ui"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"
  spec.metadata["homepage_uri"] = "https://github.com/roboruby/poetry-ui"
  spec.metadata["source_code_uri"] = "https://github.com/roboruby/poetry-ui"
  spec.metadata["changelog_uri"] = "https://github.com/roboruby/poetry-ui/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/roboruby/poetry-ui/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  # Dev-only surfaces never ship: the test/dummy host, scripts, rake tasks,
  # internal docs and design exports, the fidelity ledgers' snapshots,
  # editor/tooling files, and OS litter.
  dev_only_dirs = %w[bin/ test/ docs/ script/ rakelib/ eval/ yard/ tmp/ .github/ .ruby-lsp/ .yardoc/
                     config/theme_fidelity/ config/dictionary_fidelity/ config/upstream_
                     config/hook_coverage config/theme_states]
  dev_only_files = %w[Gemfile Gemfile.lock Rakefile AGENTS.md .gitignore .rubocop.yml .yardopts .yard_coverage
                      .herb.yml .DS_Store package.json package-lock.json vitest.config.js]
  # The fidelity ledgers and the upstream watch are development tooling driven
  # from rakelib; nothing at runtime loads them.
  dev_only_paths = %w[lib/poetry/ui/theme_fidelity.rb lib/poetry/ui/dictionary_fidelity.rb
                      lib/poetry/ui/upstream_watch.rb]
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) || f.start_with?(*dev_only_dirs) || dev_only_files.include?(File.basename(f)) ||
        dev_only_paths.include?(f)
    end
  end
  spec.require_paths = ["lib"]
  spec.bindir = "exe"

  spec.add_dependency "poetry-core", "= #{Poetry::Ui::VERSION}"
end
