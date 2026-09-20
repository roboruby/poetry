# frozen_string_literal: true

require_relative "lib/poetry/version"

Gem::Specification.new do |spec|
  spec.name = "poetry"
  spec.version = Poetry::VERSION
  spec.authors = ["Matt Solt"]
  spec.email = ["mattsolt@gmail.com"]

  spec.summary = "Poetry: the AI-native frontend framework for Rails."
  spec.description = "The Poetry umbrella gem: installs poetry-core (the Rails engine and component DSL), " \
                     "poetry-ui (the accessible, themeable, agent-legible component library) and poetry-lucide " \
                     "(the default icon set) together."
  spec.homepage = "https://poetryui.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"

  spec.metadata["homepage_uri"] = "https://poetryui.com"
  spec.metadata["documentation_uri"] = "https://poetryui.com/docs"
  spec.metadata["source_code_uri"] = "https://github.com/roboruby/poetry"
  spec.metadata["changelog_uri"] = "https://github.com/roboruby/poetry/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/roboruby/poetry/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  # A positive list: the umbrella ships its lib/ and the three root documents
  # and nothing else, however the repository root grows (gems/, site/, tools/
  # and whatever comes later can never ride along).
  shipped = %w[lib README.md CHANGELOG.md LICENSE.txt]
  tracked = begin
    IO.popen(%w[git ls-files -z --] + shipped, chdir: __dir__, err: IO::NULL) { |ls| ls.readlines("\x0", chomp: true) }
  rescue SystemCallError
    [] # no git on this machine (a slim runtime image)
  end
  # Outside a git checkout git lists nothing, so walk the same paths instead.
  tracked = Dir.chdir(__dir__) { Dir.glob(["lib/**/*", *shipped[1..]]).select { |f| File.file?(f) } } if tracked.empty?
  spec.files = tracked
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # The umbrella installs the library proper: the engine + DSL, the components,
  # and the default icon set. Charts, the agent surfaces, design extraction and
  # the simple_form bridge stay opt-in gems.
  spec.add_dependency "poetry-core", "= #{Poetry::VERSION}"
  spec.add_dependency "poetry-lucide", "= #{Poetry::VERSION}"
  spec.add_dependency "poetry-ui", "= #{Poetry::VERSION}"
end
