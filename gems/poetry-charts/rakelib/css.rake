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

# Preview scaffolding classes live in preview.rb - host safelists rightly
# never see them, so the PREVIEW-rendering build sources the files
# directly (the poetry-ui pattern). component.rb is deliberately NOT
# sourced: css:verify_rendered's teeth depend on a component-emitted bare
# string staying uncompiled.
def poetry_charts_preview_sources
  previews = Dir[Poetry::Charts.root.join("app/components/**/preview.rb").to_s]
  layout = Poetry::Charts.root.join("test/dummy/app/views/layouts/component_preview.html.erb")
  wrapper = Poetry::Core.root.join("app/views/poetry/core/preview.html.erb")
  (previews + [layout.to_s, wrapper.to_s]).sort
end

def poetry_charts_compile_tailwind(theme: poetry_charts_theme_name, extra_sources: [])
  require "tailwindcss/ruby"
  require "tmpdir"

  Dir.mktmpdir("poetry-charts-css") do |dir|
    safelist = Poetry::Core::CSS::Safelist.new(style_classes: poetry_charts_styles, template_classes: [])
    File.write(File.join(dir, "safelist.txt"), safelist.text)
    File.write(File.join(dir, "entry.css"), <<~CSS)
      @import "tailwindcss" source(none);
      @import "#{Poetry::Core.root.join("tokens/tokens.css")}";
      @import "#{Poetry::Core.root.join("tokens/tailwind-theme.css")}";
      @import "#{Poetry::Core.root.join("vendor/tw-animate-css/tw-animate.css")}";
      @import "#{Poetry::Core.root.join("vendor/shadcn-tailwind/tailwind.css")}";
      @import "#{Poetry::Core.root.join("tokens/aliases.css")}";
      @import "#{Poetry::Charts.root.join("app/assets/stylesheets/poetry-charts.css")}";
      @import "#{poetry_charts_theme_path(theme)}" layer(base);
      @source "#{File.join(dir, "safelist.txt")}";
      #{extra_sources.map { |src| %(@source "#{src}";) }.join("\n")}
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

  desc "Render every preview and verify each rendered class token exists in the compiled " \
       "preview build (safelist + preview sources) - the rendered-truth gate for the " \
       "'utilities live where the harvest sees them' rule (the poetry-ui pattern)"
  task :verify_rendered do
    poetry_charts_boot!
    require "nokogiri"

    compiled = poetry_charts_compile_tailwind(extra_sources: poetry_charts_preview_sources)
    verifier = Poetry::Core::CSS::Verifier.new(compiled_css: compiled)

    session = ActionDispatch::Integration::Session.new(Rails.application)
    tokens = {}
    pages = poetry_charts_preview_pages
    pages.each do |_component, _example, url|
      session.get(url)
      abort "HTTP #{session.response.status} at #{url}" unless session.response.successful?

      Nokogiri::HTML(session.response.body).css("[class]").each do |element|
        next if element.ancestors.any? { |ancestor| ancestor.name == "pre" }

        element["class"].split(/\s+/).each { |token| tokens[token] ||= "#{url} <#{element.name}>" }
      end
    end

    failures = verifier.unknown(tokens.keys.sort)
    if failures.any?
      report = failures.map { |unknown| "#{unknown} - first seen #{tokens[unknown.class_name]}" }
      abort "rendered class tokens missing from the compiled preview build - a component or " \
            "preview emits a utility no harvest ships (move it into a Style dictionary or " \
            "preview source):\n  #{report.join("\n  ")}"
    end

    puts "rendered-class coverage: #{tokens.size} tokens across #{pages.size} preview pages " \
         "all present in the compiled build"
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
