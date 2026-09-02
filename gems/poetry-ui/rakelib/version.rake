# frozen_string_literal: true

# The gem's VERSION is the single source of truth (no npm channel here);
# verify_tag is the release workflow's guard against tagging a stale file,
# and bump is the one-step edit the family's lockstep releases use.
def poetry_version_file = "lib/poetry/ui/version.rb"

def poetry_gem_version
  File.read(poetry_version_file)[/VERSION = "([^"]+)"/, 1] || abort("no VERSION in #{poetry_version_file}")
end

namespace :version do
  desc "Fail unless the pushed tag (GITHUB_REF_NAME) is v<Poetry::Ui::VERSION> (the release guard)"
  task :verify_tag do
    tag = ENV.fetch("GITHUB_REF_NAME") { abort "version:verify_tag reads GITHUB_REF_NAME (the pushed tag)" }
    expected = "v#{poetry_gem_version}"
    abort "tag #{tag} does not match Poetry::Ui::VERSION (#{expected})" unless tag == expected

    puts "tag #{tag} matches Poetry::Ui::VERSION"
  end

  desc "Set Poetry::Ui::VERSION: rake \"version:bump[X.Y.Z]\""
  task :bump, [:version] do |_, args|
    version = args[:version].to_s
    abort "usage: rake \"version:bump[X.Y.Z]\"" unless version.match?(/\A\d+\.\d+\.\d+(?:[.-][0-9A-Za-z.-]+)?\z/)

    source = File.read(poetry_version_file)
    abort "no VERSION in #{poetry_version_file}" unless source.match?(/VERSION = "[^"]+"/)

    File.write(poetry_version_file, source.sub(/VERSION = "[^"]+"/, %(VERSION = "#{version}")))
    puts "bumped Poetry::Ui::VERSION to #{version}; commit, then tag v#{version}"
  end
end
