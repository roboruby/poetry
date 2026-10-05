# frozen_string_literal: true

require_relative "lib/poetry/docs/version"

Gem::Specification.new do |spec|
  spec.name = "poetry-docs"
  spec.version = Poetry::Docs::VERSION
  spec.authors = [ "Matt Solt" ]
  spec.email = [ "mattsolt@gmail.com" ]
  spec.summary = "The poetryui.com documentation as a mountable Rails engine."
  spec.description = "The documentation site of Poetry, the AI-native frontend framework for Rails, as an engine a " \
                     "host mounts under its docs hostname: the guides, the component and chart pages with their " \
                     "examples, the blocks, the demos, the machine surfaces (the registry, the agent skills, the " \
                     "MCP server, llms.txt, the OpenAPI document) and the search palette, with its own layouts, " \
                     "stylesheet and JavaScript graph. Versioned with the family; not published to RubyGems, " \
                     "a host takes it from the repository at a release tag."
  spec.homepage = "https://poetryui.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"

  spec.metadata["homepage_uri"] = "https://poetryui.com"
  spec.metadata["documentation_uri"] = "https://poetryui.com/docs"
  spec.metadata["source_code_uri"] = "https://github.com/roboruby/poetry/tree/main/gems/poetry-docs"
  spec.metadata["changelog_uri"] = "https://github.com/roboruby/poetry/blob/main/gems/poetry-docs/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/roboruby/poetry/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  # The dummy host, the scripts, the evals and the Tailwind sources are
  # development surfaces; the built stylesheet under app/assets/builds ships.
  dev_only_dirs = %w[bin/ test/ script/ eval/ tailwind/ tmp/ log/ gemfiles/ .github/ .ruby-lsp/]
  dev_only_files = %w[Gemfile Gemfile.lock Rakefile AGENTS.md .gitignore .gitattributes .rubocop.yml .herb.yml
                      .ruby-version]
  tracked = begin
    IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) { |ls| ls.readlines("\x0", chomp: true) }
  rescue SystemCallError
    [] # no git on this machine (a slim runtime image)
  end
  if tracked.empty?
    tracked = Dir.chdir(__dir__) { Dir.glob("**/*", File::FNM_DOTMATCH).select { |f| File.file?(f) } }
    tracked.reject! { |f| f.start_with?(".git/", ".bundle/", "node_modules/", "coverage/", "doc/", "pkg/") }
  end
  spec.files = tracked.reject do |f|
    (f == gemspec) || f.start_with?(*dev_only_dirs) || dev_only_files.include?(File.basename(f))
  end
  spec.require_paths = [ "lib" ]

  spec.add_dependency "poetry-agent", "= #{Poetry::Docs::VERSION}"
  spec.add_dependency "poetry-charts", "= #{Poetry::Docs::VERSION}"
  spec.add_dependency "poetry-core", "= #{Poetry::Docs::VERSION}"
  spec.add_dependency "poetry-lucide", "= #{Poetry::Docs::VERSION}"
  spec.add_dependency "poetry-ui", "= #{Poetry::Docs::VERSION}"
  # The host's asset and JavaScript pipeline the layouts assume.
  spec.add_dependency "importmap-rails", ">= 2.0"
  spec.add_dependency "propshaft", ">= 1.0"
  spec.add_dependency "stimulus-rails", ">= 1.3"
  spec.add_dependency "turbo-rails", ">= 2.0"
  # The guides' live examples: the three pagination adapters and the code blocks.
  spec.add_dependency "kaminari", ">= 1.2"
  spec.add_dependency "pagy", ">= 43.0"
  spec.add_dependency "rouge", ">= 4.0"
  spec.add_dependency "will_paginate", ">= 4.0"
end
