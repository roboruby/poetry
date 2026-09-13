# frozen_string_literal: true

# The app's controllers manifest: config/controllers_manifest.json, the
# same file a gem commits, read from app/javascript/controllers by
# Poetry::Core::Stimulus::HostManifest. Registered at boot, it makes the
# app's controllers validate like poetry's: `use_stimulus` at class load,
# `poetry:check` in templates, the registry's controllers section for
# llms.txt and the MCP server. Complete or absent per controller; a
# controller the reader cannot describe is named here and stays
# unvalidated until its entry is written by hand in the same file, where
# regeneration keeps it. The file is a build artifact for the controllers
# the reader read: `poetry:check` warns and `poetry:verify` fails when
# those entries no longer match the sources; hand-written entries are the
# app's own and never count as drift.
# Loaded automatically by the engine (lib/tasks).
namespace :poetry do
  namespace :stimulus do
    desc "Write config/controllers_manifest.json from app/javascript/controllers (commit it)"
    task manifest: :environment do
      result = Poetry::Core::Stimulus::HostManifest.generate!(root: Rails.root)
      count = result.definitions.size
      puts "poetry:stimulus:manifest: wrote #{result.path.relative_path_from(Rails.root)} " \
           "(#{count} controller#{"s" unless count == 1}) - commit it; re-run after changing controllers"
      result.skipped.each do |skip|
        puts "  skipped #{skip.identifier}: #{skip.reason} (unvalidated; an entry written by hand in the file is kept)"
      end
    end
  end
end
