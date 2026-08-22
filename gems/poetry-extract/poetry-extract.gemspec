# frozen_string_literal: true

require_relative "lib/poetry/extract/version"

Gem::Specification.new do |spec|
  spec.name = "poetry-extract"
  spec.version = Poetry::Extract::VERSION
  spec.authors = ["Matt Solt"]
  spec.email = ["mattsolt@gmail.com"]

  spec.summary = "Domain in, theme out: extract a DESIGN.md + design tokens from any public website."
  spec.description = "The optional design-extraction gem for poetry: fetches a site's styleguide, " \
                     "brand, screenshot, and homepage markdown (context.dev), composes a DESIGN.md " \
                     "in one Claude call, derives Tailwind v4 @theme + CSS :root tokens " \
                     "deterministically, and hands the result to poetry's AA-gated design importer."
  spec.homepage = "https://github.com/roboruby/poetry-extract"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) || f.start_with?(*%w[test/ Gemfile .gitignore .rubocop.yml])
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "poetry-core"
  # The fetch layer's service SDK - an honest, pinned hard dependency:
  # installing this gem IS the opt-in to the external service. Pinned
  # because the SDK's source repo has vanished; bump deliberately.
  spec.add_dependency "context.dev", "~> 2.11"
end
