# frozen_string_literal: true

namespace :css do
  desc "Compile a real Tailwind build (tokens + theme + vendored animate + safelist) and verify " \
       "every Style-dictionary class against it - the gate the fresh-app proof showed was missing " \
       "(Dialog shipped tw-animate-css classes nothing provided)"
  task :verify_compiled do
    poetry_ui_boot!
    require "tailwindcss/ruby"
    require "tmpdir"

    styles = Poetry::Core::Style.descendants.select(&:name)
    templates = Poetry::Core::CSS::TemplateClasses.scan(root: Poetry::Ui.root)
    abort templates.errors.join("\n") unless templates.errors.empty?

    compiled = Dir.mktmpdir("poetry-css") do |dir|
      safelist = Poetry::Core::CSS::Safelist.new(style_classes: styles, template_classes: templates.classes)
      File.write(File.join(dir, "safelist.txt"), safelist.text)
      File.write(File.join(dir, "entry.css"), <<~CSS)
        @import "tailwindcss";
        @import "#{Poetry::Core.root.join("tokens/tokens.css")}";
        @import "#{Poetry::Core.root.join("tokens/tailwind-theme.css")}";
        @import "#{Poetry::Core.root.join("vendor/tw-animate-css/tw-animate.css")}";
        @source "#{File.join(dir, "safelist.txt")}";
      CSS
      out = File.join(dir, "out.css")
      system(Tailwindcss::Ruby.executable, "-i", File.join(dir, "entry.css"), "-o", out,
             exception: true, out: File::NULL, err: File::NULL)
      File.read(out)
    end

    verifier = Poetry::Core::CSS::Verifier.new(compiled_css: compiled)
    failures = styles.flat_map do |style|
      verifier.verify_style(style).map { |unknown| "#{style.name}: #{unknown}" }
    end
    abort "classes missing from a real Tailwind build:\n#{failures.join("\n")}" if failures.any?

    puts "all #{styles.size} Style dictionaries verified against a compiled Tailwind build"
  end
end
