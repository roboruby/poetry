# frozen_string_literal: true

require_relative "lib/poetry/core/version"

Gem::Specification.new do |spec|
  spec.name = "poetry-core"
  spec.version = Poetry::Core::VERSION
  spec.authors = ["Matt Solt"]
  spec.email = ["mattsolt@gmail.com"]

  spec.summary = "Rails engine and component DSL for poetry, the AI-native component library."
  spec.description = "The Rails engine, component DSL, and primitives of the poetry component library."
  spec.homepage = "https://github.com/roboruby/poetry-core"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/roboruby/poetry-core"
  spec.metadata["changelog_uri"] = "https://github.com/roboruby/poetry-core/blob/main/CHANGELOG.md"

  # Require MFA for gem pushes (supply-chain protection).
  spec.metadata["rubygems_mfa_required"] = "true"

  # Files shipped in the gem come from git; tooling/test/docs are excluded.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ docs/ Gemfile .gitignore .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "class_variants", "~> 1.1"
  spec.add_dependency "rails", "~> 8.0"
  spec.add_dependency "tailwind_merge", "~> 1.3"
  spec.add_dependency "view_component", "~> 4.0"
  spec.add_dependency "zeitwerk", "~> 2.6"
end
