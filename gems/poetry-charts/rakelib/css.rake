# frozen_string_literal: true

# The compiled-CSS drift gate, ported from poetry-ui: compile the
# real Tailwind build a host produces (tokens + theme + vendored utilities +
# this gem's safelist) and verify every charts Style dictionary against it,
# so a dictionary class nothing provides can never pass CI while failing in
# a host. Charts templates carry no static classes yet (everything routes
# through css(:part)); the template-class machinery ports when they do.

def poetry_charts_boot!
  ENV["RAILS_ENV"] ||= "test"
  ENV["COVERAGE"] ||= "0"
  require_relative "../test/dummy/config/environment"
  Rails.application.eager_load!
end

def poetry_charts_styles
  Poetry::Core::Style.descendants.select { |style| style.name&.start_with?("Poetry::Charts::") }
end

# The theme roster (N12), mirroring poetry-ui: every themes/*.css fragment
# is a complete visual theme; POETRY_THEME picks one, unset loops all.
def poetry_charts_theme_names
  Dir[Poetry::Charts.root.join("themes/*.css").to_s].map { |file| File.basename(file, ".css") }.sort
end

def poetry_charts_theme_name = ENV.fetch("POETRY_THEME", "default")

def poetry_charts_theme_path(name = poetry_charts_theme_name)
  path = Poetry::Charts.root.join("themes/#{name}.css")
  unless path.exist?
    abort "unknown poetry theme #{name.inspect} - poetry-charts ships: #{poetry_charts_theme_names.join(", ")}"
  end
  path
end

def poetry_charts_gate_themes
  ENV["POETRY_THEME"] ? [poetry_charts_theme_name] : poetry_charts_theme_names
end

def poetry_charts_compile_tailwind(theme: poetry_charts_theme_name)
  require "tailwindcss/ruby"
  require "tmpdir"

  Dir.mktmpdir("poetry-charts-css") do |dir|
    safelist = Poetry::Core::CSS::Safelist.new(style_classes: poetry_charts_styles, template_classes: [])
    File.write(File.join(dir, "safelist.txt"), safelist.text)
    File.write(File.join(dir, "entry.css"), <<~CSS)
      @import "tailwindcss";
      @import "#{Poetry::Core.root.join("tokens/tokens.css")}";
      @import "#{Poetry::Core.root.join("tokens/tailwind-theme.css")}";
      @import "#{Poetry::Core.root.join("vendor/tw-animate-css/tw-animate.css")}";
      @import "#{Poetry::Core.root.join("vendor/shadcn-tailwind/tailwind.css")}";
      @import "#{Poetry::Core.root.join("tokens/aliases.css")}";
      @import "#{Poetry::Charts.root.join("app/assets/stylesheets/poetry-charts.css")}";
      @import "#{poetry_charts_theme_path(theme)}" layer(base);
      @source "#{File.join(dir, "safelist.txt")}";
    CSS
    out = File.join(dir, "out.css")
    system(Tailwindcss::Ruby.executable, "-i", File.join(dir, "entry.css"), "-o", out,
           exception: true, out: File::NULL, err: File::NULL)
    File.read(out)
  end
end

namespace :css do
  desc "Compile a real Tailwind build and verify every charts Style dictionary against it (per theme)"
  task :verify_compiled do
    poetry_charts_boot!

    styles = poetry_charts_styles

    poetry_charts_gate_themes.each do |theme|
      compiled = poetry_charts_compile_tailwind(theme: theme)

      verifier = Poetry::Core::CSS::Verifier.new(compiled_css: compiled)
      failures = styles.flat_map do |style|
        verifier.verify_style(style).map { |unknown| "#{style.name}: #{unknown}" }
      end
      abort "classes missing from a real Tailwind build (theme #{theme}):\n#{failures.join("\n")}" if failures.any?

      puts "all #{styles.size} charts Style dictionaries verified against a compiled Tailwind build (theme #{theme})"
    end
  end

  desc "Verify bidirectional cn-* coverage between the charts Style dictionaries and every themes/*.css (N12)"
  task :verify_theme do
    poetry_charts_boot!

    styles = poetry_charts_styles
    poetry_charts_gate_themes.each do |theme|
      coverage = Poetry::Core::CSS::ThemeCoverage.new(
        theme_css: poetry_charts_theme_path(theme).read,
        style_classes: styles,
        allowlist: []
      )

      problems = coverage.missing.map { |name| "missing theme rule: #{name}" } +
                 coverage.orphans.map { |name| "orphan theme rule: #{name}" }
      abort "theme coverage (themes/#{theme}.css):\n  #{problems.join("\n  ")}" unless problems.empty?

      puts "theme coverage (#{theme}): #{coverage.theme_names.size} cn rules <-> " \
           "#{coverage.dictionary_names.size} dictionary names"
    end
  end
end
