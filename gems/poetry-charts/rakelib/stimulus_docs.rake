# frozen_string_literal: true

# The controller documentation floor, the shape of yard:coverage:all for
# the JavaScript side: the committed controllers manifest carries the
# prose harvested beside each controller (its purpose, each value's
# meaning, each action's summary); this counts what is missing and holds
# the count at the committed floor, which only goes down. Regenerate the
# manifest with npm run manifest; lower the floor with stimulus:docs:record.
namespace :stimulus do
  desc "Count the controllers, values and action methods without prose in the manifest"
  task :docs do
    missing = stimulus_docs_missing
    floor_path = ".controller_docs"
    abort "stimulus:docs: no .controller_docs - run stimulus:docs:record" unless File.exist?(floor_path)

    floor = File.read(floor_path).to_i
    if missing.size > floor
      abort "stimulus:docs: #{missing.size} without prose (floor #{floor}):\n  #{missing.join("\n  ")}"
    end

    puts "stimulus:docs: #{missing.size} without prose (floor #{floor})"
  end

  namespace :docs do
    desc "Record the current count as the floor"
    task :record do
      File.write(".controller_docs", "#{stimulus_docs_missing.size}\n")
      puts "recorded controller docs floor: #{stimulus_docs_missing.size}"
    end
  end
end

# Every gap, one line each: the controller without a purpose, the value
# without a meaning, the action method without a summary.
def stimulus_docs_missing
  require "json"
  manifest = JSON.parse(File.read("config/controllers_manifest.json"))
  manifest.flat_map do |identifier, entry|
    gaps = []
    gaps << "#{identifier}: no purpose" unless entry["doc"]
    entry.fetch("values", {}).each { |name, value| gaps << "#{identifier}: value #{name}" unless value["doc"] }
    docs = entry.fetch("method_docs", {})
    entry.fetch("methods", []).each { |name| gaps << "#{identifier}: method #{name}" unless docs[name] }
    gaps
  end
end
