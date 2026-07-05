# frozen_string_literal: true

require_relative "lib/poetry/charts/version"

Gem::Specification.new do |spec|
  spec.name = "poetry-charts"
  spec.version = Poetry::Charts::VERSION
  spec.authors = ["Matt Solt"]
  spec.email = ["mattsolt@gmail.com"]

  spec.summary = "poetry's chart tier: the shadcn chart surface as server-rendered SVG."
  spec.description = "Charts whose geometry is computed on the server (Ruby; d3-scale/d3-shape " \
                     "semantics, recharts' nice ticks) and shipped as finished SVG - no-JS valid, " \
                     "CSS-variable themed, zero client chart math. Stimulus chrome reads " \
                     "server-embedded coordinates for tooltips and legends; engines stay swappable " \
                     "behind a closed, versioned chart-spec (Chart.js reference adapter)."
  spec.homepage = "https://github.com/roboruby/poetry-charts"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/roboruby/poetry-charts"
  spec.metadata["changelog_uri"] = "https://github.com/roboruby/poetry-charts/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ docs/ Gemfile .gitignore .github/ .rubocop.yml])
    end
  end
  spec.require_paths = ["lib"]

  # Same single dependency as poetry-ui: the component model, Style
  # dictionaries, Stimulus::Builder, and HTML::Attributes all come from core.
  # poetry-ui is deliberately NOT required - the chart frame is
  # self-contained; composition with poetry-ui components happens in hosts.
  spec.add_dependency "poetry-core"
end
