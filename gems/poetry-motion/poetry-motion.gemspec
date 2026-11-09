# frozen_string_literal: true

require_relative "lib/poetry/motion/version"

Gem::Specification.new do |spec|
  spec.name = "poetry-motion"
  spec.version = Poetry::Motion::VERSION
  spec.authors = ["Matt Solt"]
  spec.email = ["mattsolt@gmail.com"]

  spec.summary = "Poetry's motion tier: springs, scroll, pointer and layout animation for Rails."
  spec.description = "Opt-in animated effects for Poetry. The server renders every effect's finished " \
                     "state; a vendored animation engine loads only on the pages that ask for it, " \
                     "and one motion policy handles reduced motion, the Turbo cache and morphs."
  spec.homepage = "https://poetryui.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"
  spec.metadata["homepage_uri"] = "https://poetryui.com"
  spec.metadata["documentation_uri"] = "https://poetryui.com/docs"
  spec.metadata["source_code_uri"] = "https://github.com/roboruby/poetry/tree/main/gems/poetry-motion"
  spec.metadata["changelog_uri"] = "https://github.com/roboruby/poetry/blob/main/gems/poetry-motion/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/roboruby/poetry/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  # Dev-only surfaces never ship: tests, rake tasks, the kernel's build
  # inputs, and editor/tooling files.
  dev_only_dirs = %w[bin/ test/ docs/ script/ rakelib/ gemfiles/ tmp/ vendor/ .github/ .ruby-lsp/ .yardoc/]
  dev_only_files = %w[Gemfile Gemfile.lock Rakefile AGENTS.md .gitignore .rubocop.yml .yardopts .yard_coverage
                      package.json package-lock.json vitest.config.js]
  tracked = begin
    IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) { |ls| ls.readlines("\x0", chomp: true) }
  rescue SystemCallError
    []
  end
  if tracked.empty?
    tracked = Dir.chdir(__dir__) { Dir.glob("**/*", File::FNM_DOTMATCH).select { |f| File.file?(f) } }
    tracked.reject! { |f| f.start_with?(".git/", ".bundle/", "node_modules/", "coverage/", "doc/", "pkg/") }
  end
  spec.files = tracked.reject do |f|
    (f == gemspec) || f.start_with?(*dev_only_dirs) || dev_only_files.include?(File.basename(f))
  end
  # The minified JavaScript the release writes into dist/ beside the source.
  # git does not track it, so it joins the list here; the engine serves it.
  spec.files |= Dir.glob("dist/**/*", base: __dir__).select { |f| File.file?(File.join(__dir__, f)) }
  spec.require_paths = ["lib"]

  # poetry-core for the component model and behaviors. poetry-ui is not
  # required: an effect that wraps a ui component (the tilt card around
  # Card) needs the host to bundle poetry-ui, and says so at render.
  spec.add_dependency "poetry-core", "= #{Poetry::Motion::VERSION}"
end
