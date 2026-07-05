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
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/roboruby/poetry-ui"
  spec.metadata["changelog_uri"] = "https://github.com/roboruby/poetry-ui/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ eval/ Gemfile .gitignore .github/ .rubocop.yml])
    end
  end
  spec.require_paths = ["lib"]
  spec.bindir = "exe"
  spec.executables = ["poetry-agent"]

  spec.add_dependency "poetry-core"
end
