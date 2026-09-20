# frozen_string_literal: true

require_relative "lib/poetry/extract/version"

Gem::Specification.new do |spec|
  spec.name = "poetry-extract"
  spec.version = Poetry::Extract::VERSION
  spec.authors = ["Matt Solt"]
  spec.email = ["mattsolt@gmail.com"]

  spec.summary = "Domain in, theme out: extract a DESIGN.md + design tokens from any public website."
  spec.description = "The optional design-extraction gem for Poetry: fetches a site's styleguide, brand, " \
                     "screenshot, and homepage markdown (context.dev), composes a DESIGN.md in one Claude call, " \
                     "derives Tailwind v4 @theme + CSS :root tokens deterministically, and hands the result to " \
                     "Poetry's AA-gated design importer."
  spec.homepage = "https://poetryui.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"
  spec.metadata["homepage_uri"] = "https://poetryui.com"
  spec.metadata["documentation_uri"] = "https://poetryui.com/docs"
  spec.metadata["source_code_uri"] = "https://github.com/roboruby/poetry/tree/main/gems/poetry-extract"
  spec.metadata["changelog_uri"] = "https://github.com/roboruby/poetry/blob/main/gems/poetry-extract/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/roboruby/poetry/issues"
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
  tracked = begin
    IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) { |ls| ls.readlines("\x0", chomp: true) }
  rescue SystemCallError
    [] # no git on this machine (a slim runtime image)
  end
  if tracked.empty?
    # Outside a git checkout (a deploy image, a path gem beside a host app) git
    # lists nothing, so walk the tree instead; the rejects below still apply.
    tracked = Dir.chdir(__dir__) { Dir.glob("**/*", File::FNM_DOTMATCH).select { |f| File.file?(f) } }
    tracked.reject! { |f| f.start_with?(".git/", ".bundle/", "node_modules/", "coverage/", "doc/", "pkg/") }
  end
  spec.files = tracked.reject do |f|
    (f == gemspec) || f.start_with?(*dev_only_dirs) || dev_only_files.include?(File.basename(f))
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "poetry-core", "= #{Poetry::Extract::VERSION}"
  # The fetch layer's service SDK - an honest, pinned hard dependency:
  # installing this gem IS the opt-in to the external service. Pinned
  # because the SDK's source repo has vanished; bump deliberately.
  spec.add_dependency "context.dev", "~> 2.11"
end
