# frozen_string_literal: true

# Complexity and duplication as a report, never a gate: flog scores every
# method (higher is denser) and flay finds structurally repeated code.
# Both are single numbers with no false-positive control, so no threshold
# holds them; the ten worst of each are the refactor queue, read by hand.
# Shipped Ruby (lib, app) and tooling (rakelib, exe, bin) score apart, as
# do the templates: a rake block counts as one method, and template
# families share their shape on purpose. Previews stay out: demo code
# repeats by design.
namespace :quality do
  desc "The ten densest methods and the ten largest duplicates, shipped code and tooling apart"
  task :report do
    require "flog"
    require "flay"

    preview = ->(file) { file.start_with?("app/") && file.include?("preview") }
    shipped = Dir.glob("{lib,app}/**/*.rb").reject(&preview)
    tooling = Dir.glob("{rakelib,exe,bin}/**/*").select do |file|
      File.file?(file) && (file.end_with?(".rake", ".rb") || File.read(file, 60).to_s.include?("ruby"))
    end
    templates = Dir.glob("app/**/*.erb").reject(&preview)
    Flay.load_plugins if templates.any?

    QualityReport.flog("shipped Ruby (lib, app)", shipped)
    QualityReport.flog("tooling (rakelib, exe, bin)", tooling)
    QualityReport.flay("Ruby (lib, app)", shipped)
    QualityReport.flay("templates (app/**/*.erb)", templates)
  end
end

# The two halves of the report, each printing one section.
module QualityReport
  module_function

  # Prints the ten densest methods in the files, after the count, total and average.
  def flog(label, files)
    return puts("flog #{label}: no files\n\n") if files.empty?

    scorer = Flog.new(all: true, methods: true, continue: true, quiet: true)
    scorer.flog(*files)
    puts format("flog %<label>s: %<count>d methods, total %<total>.0f, average %<average>.1f",
                label: label, count: scorer.calls.size, total: scorer.total_score, average: scorer.average)
    densest(scorer).each do |score, name, where|
      puts format("  %<score>6.1f  %<name>s  %<where>s", score: score, name: name, where: where)
    end
    puts
  end

  # The ten highest-scoring methods: score, name and location.
  def densest(scorer)
    rows = []
    scorer.each_by_score do |name, score, _calls|
      rows << [score, name, scorer.method_locations[name]]
      break if rows.size == 10
    end
    rows
  end

  # Prints the ten largest duplicates in the files, after the total mass and the count.
  def flay(label, files)
    return puts("flay #{label}: no files\n\n") if files.empty?

    finder = Flay.new(mass: 16)
    finder.process(*files)
    items = finder.analyze
    puts "flay #{label}: total mass #{finder.total}, #{items.size} duplicates of mass 16 or more"
    items.first(10).each { |item| puts duplicate_line(item) }
    puts
  end

  # One duplicate as a line: its mass, whether identical, its node type and every location.
  def duplicate_line(item)
    kind = item.bonus ? "identical" : "similar"
    where = item.locations.map { |location| "#{location.file}:#{location.line}" }.join(", ")
    format("  %<mass>5d  %<kind>s %<name>s  %<where>s", mass: item.mass, kind: kind, name: item.name, where: where)
  end
end
