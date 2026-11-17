# frozen_string_literal: true

# Applies the renames `poetry:check` warns about to the app's templates:
# an option a component retired in favour of another, and an icon its set
# renamed. Each is one name on one line, replaced where the warning
# points; a name written twice on its line is left alone and listed.
# `DRY_RUN=1 bin/rails poetry:rename` lists the changes and writes nothing.
# Loaded automatically by the engine (lib/tasks).
namespace :poetry do
  desc "Apply the renames poetry:check warns about (a retired option, a renamed icon); DRY_RUN=1 only lists them"
  task :rename, [:glob] => :environment do |_task, args|
    unless Poetry::Core::CSS::TemplateClasses.available?
      abort "poetry:rename: the herb gem is required to parse templates - " \
            "`bin/rails g poetry:install` adds it to your development group"
    end

    patterns = args[:glob] ? [args[:glob]] : ["app/{views,components}/**/*.html.erb", "app/**/*.rb"]
    paths = patterns.flat_map { |pattern| Dir.glob(Rails.root.join(pattern).to_s) }.uniq
    findings = Poetry::Core::Check::Runner.new(Poetry::Ui::CheckCatalog.build(root: Rails.root))
                                          .run(paths, root: Rails.root)
    dry = ENV["DRY_RUN"] == "1"
    changes = Poetry::Core::Check::Renames.new(findings, root: Rails.root).apply(write: !dry)
    made, left = changes.partition(&:applied)

    place = ->(change) { "#{change.file.to_s.delete_prefix("#{Rails.root}/")}:#{change.line}" }
    made.each { |change| puts "#{place.call(change)}: #{change.from} -> #{change.to}" }
    left.each { |change| warn "#{place.call(change)}: #{change.from} left as it is (#{change.reason})" }
    puts "poetry:rename: #{made.size} rename#{"s" unless made.size == 1} #{dry ? "to make" : "made"}" \
         "#{", #{left.size} left for you" if left.any?}"
  end
end
