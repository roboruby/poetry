# frozen_string_literal: true

require_relative "lib/poetry/version"

Gem::Specification.new do |spec|
  spec.name = "poetry"
  spec.version = Poetry::VERSION
  spec.authors = ["Matt Solt"]
  spec.email = ["mattsolt@gmail.com"]

  spec.summary = "Poetry, the AI-native UI component library for Rails: shadcn-parity ViewComponents on " \
                 "Hotwire and Tailwind."
  spec.description = "The Poetry umbrella gem: installs poetry-core (the Rails engine and component DSL), " \
                     "poetry-ui (the accessible, themeable, agent-legible component library) and poetry-lucide " \
                     "(the default icon set) together."
  spec.homepage = "https://poetryui.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  # Uncomment the line below to require MFA for gem pushes.
  # This helps protect your gem from supply chain attacks by ensuring
  # no one can publish a new version without multi-factor authentication.
  # See: https://guides.rubygems.org/mfa-requirement-opt-in/
  spec.metadata["homepage_uri"] = "https://poetryui.com"
  spec.metadata["documentation_uri"] = "https://poetryui.com/docs"
  spec.metadata["source_code_uri"] = "https://github.com/roboruby/poetry"
  spec.metadata["changelog_uri"] = "https://github.com/roboruby/poetry/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/roboruby/poetry/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
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

  # The umbrella installs the library proper: the engine + DSL, the components,
  # and the default icon set. Charts, the agent surfaces, design extraction and
  # the simple_form bridge stay opt-in gems.
  spec.add_dependency "poetry-core", "= #{Poetry::VERSION}"
  spec.add_dependency "poetry-lucide", "= #{Poetry::VERSION}"
  spec.add_dependency "poetry-ui", "= #{Poetry::VERSION}"

  # For more information and examples about making a new gem, check out our
  # guide at: https://guides.rubygems.org/make-your-own-gem/
end
