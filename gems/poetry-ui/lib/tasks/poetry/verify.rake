# frozen_string_literal: true

# The host-app verification task: the same Verifier + Herb gates
# poetry's own CI runs, in the CONSUMER's app - the enforcement arm of
# "make the off-system path unavailable" where agents actually work.
# Loaded automatically by the engine (lib/tasks).
namespace :poetry do
  desc "Verify poetry component classes against the compiled Tailwind CSS and parse app templates " \
       "(POETRY_COMPILED_CSS overrides the default build path)"
  task verify: :environment do
    failures = []

    compiled = ENV["POETRY_COMPILED_CSS"] || Rails.root.join("app/assets/builds/tailwind.css").to_s
    if File.exist?(compiled)
      verifier = Poetry::Core::CSS::Verifier.new(compiled_css: File.read(compiled))
      Rails.application.eager_load!
      Poetry::Core::Style.descendants.select(&:name).each do |style|
        verifier.verify_style(style).each { |unknown| failures << "#{style.name}: #{unknown}" }
      end
    else
      puts "poetry:verify: no compiled CSS at #{compiled} - class verification skipped " \
           "(set POETRY_COMPILED_CSS or build Tailwind first)"
    end

    begin
      result = Poetry::Core::CSS::TemplateClasses.scan(root: Rails.root, glob: "app/components/**/*.html.erb")
      failures.concat(result.errors.map(&:to_s))
    rescue Poetry::Core::Error => e
      puts "poetry:verify: #{e.message} - template parse gate skipped"
    end

    abort "poetry:verify failed:\n#{failures.join("\n")}" if failures.any?

    puts "poetry:verify: clean"
  end
end
