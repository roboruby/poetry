# frozen_string_literal: true

# The gem's VERSION is the single source of truth (no npm channel here, so
# there is nothing to keep in step with it); verify_tag is the release
# workflow's guard against tagging a stale file, and bump is the one-step
# edit the family's lockstep releases use.
def poetry_version_file = "lib/poetry/lucide/version.rb"

def poetry_gem_version
  File.read(poetry_version_file)[/VERSION = "([^"]+)"/, 1] || abort("no VERSION in #{poetry_version_file}")
end

namespace :version do
  desc "Fail unless the pushed tag (GITHUB_REF_NAME) is v<Poetry::Lucide::VERSION> (the release guard)"
  task :verify_tag do
    tag = ENV.fetch("GITHUB_REF_NAME") { abort "version:verify_tag reads GITHUB_REF_NAME (the pushed tag)" }
    expected = "v#{poetry_gem_version}"
    abort "tag #{tag} does not match Poetry::Lucide::VERSION (#{expected})" unless tag == expected

    puts "tag #{tag} matches Poetry::Lucide::VERSION"
  end

  desc "Set Poetry::Lucide::VERSION: rake \"version:bump[X.Y.Z]\""
  task :bump, [:version] do |_, args|
    version = args[:version].to_s
    abort "usage: rake \"version:bump[X.Y.Z]\"" unless version.match?(/\A\d+\.\d+\.\d+(?:[.-][0-9A-Za-z.-]+)?\z/)

    source = File.read(poetry_version_file)
    abort "no VERSION in #{poetry_version_file}" unless source.match?(/VERSION = "[^"]+"/)

    File.write(poetry_version_file, source.sub(/VERSION = "[^"]+"/, %(VERSION = "#{version}")))
    puts "bumped Poetry::Lucide::VERSION to #{version}; commit, then tag v#{version}"
  end
end
