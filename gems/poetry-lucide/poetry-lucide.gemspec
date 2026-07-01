# frozen_string_literal: true

require_relative "lib/poetry/lucide/version"

Gem::Specification.new do |spec|
  spec.name = "poetry-lucide"
  spec.version = Poetry::Lucide::VERSION
  spec.authors = ["Matt Solt"]
  spec.email = ["mattsolt@gmail.com"]

  spec.summary = "Lucide icons for poetry, vendored and sanitized at a pinned upstream commit."
  spec.description = "The default poetry icon set: Lucide's icons vendored at a pinned " \
                     "commit SHA, sanitized at vendor time, registered with poetry-core's icon registry."
  spec.homepage = "https://github.com/roboruby/poetry-lucide"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) || f.start_with?(*%w[script/ test/ Gemfile .gitignore .rubocop.yml])
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "poetry-core"
end
