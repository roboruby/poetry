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

def poetry_charts_compile_tailwind
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
      @source "#{File.join(dir, "safelist.txt")}";
    CSS
    out = File.join(dir, "out.css")
    system(Tailwindcss::Ruby.executable, "-i", File.join(dir, "entry.css"), "-o", out,
           exception: true, out: File::NULL, err: File::NULL)
    File.read(out)
  end
end

namespace :css do
  desc "Compile a real Tailwind build and verify every charts Style dictionary against it"
  task :verify_compiled do
    poetry_charts_boot!

    compiled = poetry_charts_compile_tailwind
    styles = poetry_charts_styles

    verifier = Poetry::Core::CSS::Verifier.new(compiled_css: compiled)
    failures = styles.flat_map do |style|
      verifier.verify_style(style).map { |unknown| "#{style.name}: #{unknown}" }
    end
    abort "classes missing from a real Tailwind build:\n#{failures.join("\n")}" if failures.any?

    puts "all #{styles.size} charts Style dictionaries verified against a compiled Tailwind build"
  end
end
