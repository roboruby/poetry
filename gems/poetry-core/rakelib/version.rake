# frozen_string_literal: true

# The gem's VERSION is the single source of truth; package.json (the npm
# channel for bundler hosts) and its lock must carry the same number. The
# family bumps in lockstep on the maintainer's explicit go, so a bump is one
# task here, verify is the drift gate in the default chain, and verify_tag
# is the release workflow's guard against tagging a stale file.
def poetry_version_file = "lib/poetry/core/version.rb"

def poetry_gem_version
  File.read(poetry_version_file)[/VERSION = "([^"]+)"/, 1] || abort("no VERSION in #{poetry_version_file}")
end

def poetry_npm_versions
  require "json"
  found = { "package.json" => JSON.parse(File.read("package.json"))["version"] }
  if File.exist?("package-lock.json")
    lock = JSON.parse(File.read("package-lock.json"))
    found["package-lock.json"] = lock["version"]
    found["package-lock.json (root package)"] = lock.dig("packages", "", "version")
  end
  found
end

namespace :version do
  desc "Fail if package.json or its lock disagree with Poetry::Core::VERSION"
  task :verify do
    gem_version = poetry_gem_version
    drift = poetry_npm_versions.reject { |_, version| version == gem_version }
    if drift.empty?
      puts "versions in sync (#{gem_version})"
    else
      listed = drift.map { |file, version| "#{file}=#{version.inspect}" }.join(", ")
      abort "version drift from Poetry::Core::VERSION #{gem_version}: #{listed} - " \
            "run `bundle exec rake \"version:bump[#{gem_version}]\"` and commit"
    end
  end

  desc "Fail unless the pushed tag (GITHUB_REF_NAME) is v<Poetry::Core::VERSION> (the release guard)"
  task :verify_tag do
    tag = ENV.fetch("GITHUB_REF_NAME") { abort "version:verify_tag reads GITHUB_REF_NAME (the pushed tag)" }
    expected = "v#{poetry_gem_version}"
    abort "tag #{tag} does not match Poetry::Core::VERSION (#{expected})" unless tag == expected

    puts "tag #{tag} matches Poetry::Core::VERSION"
  end

  desc "Set Poetry::Core::VERSION and the npm package version together: rake \"version:bump[X.Y.Z]\""
  task :bump, [:version] do |_, args|
    version = args[:version].to_s
    abort "usage: rake \"version:bump[X.Y.Z]\"" unless version.match?(/\A\d+\.\d+\.\d+(?:[.-][0-9A-Za-z.-]+)?\z/)

    source = File.read(poetry_version_file)
    abort "no VERSION in #{poetry_version_file}" unless source.match?(/VERSION = "[^"]+"/)

    File.write(poetry_version_file, source.sub(/VERSION = "[^"]+"/, %(VERSION = "#{version}")))
    sh "npm", "version", version, "--no-git-tag-version", "--allow-same-version"
    puts "bumped Poetry::Core::VERSION and package.json to #{version}; commit, then tag v#{version}"
  end
end
