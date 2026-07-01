# frozen_string_literal: true

# The M2 CSS toolchain tasks. These boot the on-disk dummy host so the
# engine's Style classes are loadable, then operate on every Style
# dictionary + the component templates.

def poetry_css_boot!
  ENV["RAILS_ENV"] ||= "test"
  ENV["COVERAGE"] ||= "0"
  require_relative "../test/dummy/config/environment"
  Rails.application.eager_load!
end

def poetry_style_classes
  Poetry::Core::Style.descendants.select(&:name)
end

namespace :css do
  desc "Generate the Tailwind safelist (every Style-dictionary class + static template classes) to tmp/"
  task :safelist do
    poetry_css_boot!
    templates = Poetry::Core::CSS::TemplateClasses.scan(root: Poetry::Core.root)
    abort templates.errors.join("\n") unless templates.errors.empty?

    safelist = Poetry::Core::CSS::Safelist.new(style_classes: poetry_style_classes,
                                               template_classes: templates.classes)
    path = Poetry::Core.root.join("tmp/poetry-safelist.txt")
    path.dirname.mkpath
    path.write(safelist.text)
    puts "wrote #{path} (#{safelist.classes.size} classes)"
  end

  desc "Verify every Style-dictionary class against a compiled Tailwind stylesheet " \
       "(rake 'css:verify[path/to/tailwind.css]')"
  task :verify, [:compiled_css] do |_t, args|
    abort "usage: rake 'css:verify[path/to/compiled/tailwind.css]'" unless args[:compiled_css]

    poetry_css_boot!
    verifier = Poetry::Core::CSS::Verifier.new(compiled_css: File.read(args[:compiled_css]))
    failures = poetry_style_classes.flat_map do |style|
      verifier.verify_style(style).map { |unknown| "#{style.name}: #{unknown}" }
    end
    abort "unknown classes (not in the compiled CSS):\n#{failures.join("\n")}" unless failures.empty?

    puts "all Style dictionary classes verified against #{args[:compiled_css]}"
  end

  desc "Emit the :bem reference stylesheets (one per Style dictionary) to tmp/"
  task :bem_reference do
    poetry_css_boot!
    path = Poetry::Core.root.join("tmp/poetry-bem-reference.css")
    path.dirname.mkpath
    stylesheets = poetry_style_classes.filter_map do |style|
      Poetry::Core::CSS::BemReference.new(style).css if style.bem_block
    end
    path.write(stylesheets.join("\n\n"))
    puts "wrote #{path} (#{stylesheets.size} blocks)"
  end

  desc "Herb parse gate: fail if any component template has HTML+ERB parse errors"
  task :herb do
    poetry_css_boot!
    result = Poetry::Core::CSS::TemplateClasses.scan(root: Poetry::Core.root)
    abort "herb parse errors:\n#{result.errors.join("\n")}" unless result.errors.empty?

    puts "herb: all component templates parse clean"
  end
end
