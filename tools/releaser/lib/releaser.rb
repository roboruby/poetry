# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "net/http"
require "open3"
require "uri"

# The release mechanics for the Poetry family, driven by rake from
# tools/releaser locally and by the Release workflow. Every decision is a
# plain method the tests cover; the network and git calls are small and
# separate so nothing here needs a runner to be understood.
module Releaser
  ROOT = File.expand_path("../../..", __dir__)
  # Publish order: dependencies first, the umbrella last.
  GEMS = %w[poetry-core poetry-lucide poetry-charts poetry-extract poetry-ui poetry-agent poetry-simple_form
            poetry].freeze
  # The package.json trees the family versions in lockstep.
  PACKAGES = %w[gems/poetry-core gems/poetry-charts gems/poetry-agent].freeze
  # What the umbrella gem may ship, and nothing else.
  UMBRELLA_DOCS = %w[README.md CHANGELOG.md LICENSE.txt].freeze
  ISSUER = "https://token.actions.githubusercontent.com"
  NO_CHANGES = "- Version bump with the family; no changes in this gem."

  class Error < StandardError; end

  def self.version(root = ROOT) = File.read(File.join(root, "VERSION")).strip
  def self.gem_dir(name, root = ROOT) = name == "poetry" ? root : File.join(root, "gems", name)
  def self.gem_file(name, version) = "#{name}-#{version}.gem"

  # VERSION into every version.rb and package.json.
  module Versions
    def self.version_file(root, name)
      Dir.glob(File.join(Releaser.gem_dir(name, root), "lib/**/version.rb")).min_by(&:length) or
        raise Error, "no version.rb under #{Releaser.gem_dir(name, root)}"
    end

    # Rewrites every file to the version; returns the paths that changed.
    def self.stamp(root, version)
      changed = []
      GEMS.each do |name|
        path = version_file(root, name)
        text = File.read(path)
        raise Error, "no VERSION constant in #{path}" unless text.match?(/VERSION = "[^"]+"/)

        updated = text.sub(/VERSION = "[^"]+"/, "VERSION = \"#{version}\"")
        next if updated == text

        File.write(path, updated)
        changed << path
      end
      PACKAGES.each do |dir|
        path = File.join(root, dir, "package.json")
        text = File.read(path)
        updated = text.sub(/^(\s*"version":\s*")[^"]+(")/) { "#{Regexp.last_match(1)}#{version}#{Regexp.last_match(2)}" }
        unless updated == text
          File.write(path, updated)
          changed << path
        end
        lock = File.join(root, dir, "package-lock.json")
        changed << lock if File.exist?(lock) && stamp_lock(lock, version)
      end
      changed
    end

    # npm's lock names the package's version twice (the root and the ""
    # package); npm writes it as JSON.stringify(obj, null, 2), which a Ruby
    # round trip reproduces byte for byte.
    def self.stamp_lock(path, version)
      lock = JSON.parse(File.read(path))
      before = [lock["version"], lock.dig("packages", "", "version")]
      lock["version"] = version
      lock["packages"][""]["version"] = version if lock.dig("packages", "")
      return false if before.uniq == [version]

      File.write(path, "#{JSON.pretty_generate(lock)}\n")
      true
    end

    # Every file that disagrees with the version, as "path: found".
    def self.mismatches(root, version)
      out = []
      GEMS.each do |name|
        path = version_file(root, name)
        found = File.read(path)[/VERSION = "([^"]+)"/, 1]
        out << "#{path}: #{found.inspect}" unless found == version
      end
      PACKAGES.each do |dir|
        path = File.join(root, dir, "package.json")
        found = JSON.parse(File.read(path))["version"]
        out << "#{path}: #{found.inspect}" unless found == version
        lock = File.join(root, dir, "package-lock.json")
        next unless File.exist?(lock)

        parsed = JSON.parse(File.read(lock))
        [parsed["version"], parsed.dig("packages", "", "version")].each do |found_in_lock|
          out << "#{lock}: #{found_in_lock.inspect}" unless found_in_lock == version
        end
      end
      out
    end
  end

  # Keep a Changelog files, one per gem: "## [X]" heads the work in progress
  # and gains its date at release.
  module Changelog
    def self.undated(version) = /^## \[#{Regexp.escape(version)}\]$/
    def self.dated(version) = /^## \[#{Regexp.escape(version)}\] - \d{4}-\d{2}-\d{2}$/
    def self.any(version) = /^## \[#{Regexp.escape(version)}\](?: - \d{4}-\d{2}-\d{2})?$/

    # Dates the version's heading, or inserts a no-changes section when the
    # gem has none. Returns :dated, :inserted or :unchanged.
    def self.date(path, version, date)
      text = File.read(path)
      return :unchanged if text.match?(dated(version))

      if text.match?(undated(version))
        File.write(path, text.sub(undated(version), "## [#{version}] - #{date}"))
        :dated
      else
        section = "## [#{version}] - #{date}\n\n### Changed\n\n#{NO_CHANGES}\n\n"
        updated = text.sub(/^## \[/) { "#{section}## [" }
        updated = "#{text.rstrip}\n\n#{section.rstrip}\n" if updated == text
        File.write(path, updated)
        :inserted
      end
    end

    # The body of the version's section without its heading, or nil.
    def self.section(path, version)
      lines = File.read(path).lines
      start = lines.index { |l| l.match?(any(version)) } or return nil
      rest = lines[(start + 1)..]
      stop = rest.index { |l| l.start_with?("## [") } || rest.size
      rest[0...stop].join.strip
    end
  end

  # The GitHub release notes: every gem's section for the version.
  module Notes
    def self.assemble(root, version)
      parts = GEMS.map do |name|
        body = Changelog.section(File.join(Releaser.gem_dir(name, root), "CHANGELOG.md"), version) || NO_CHANGES
        "## #{name}\n\n#{body}"
      end
      "# Poetry #{version}\n\n#{parts.join("\n\n")}\n"
    end
  end

  # gem build for all eight, reproducible: SOURCE_DATE_EPOCH is the commit
  # time of the ref under release, so a rebuild is byte-identical.
  module Build
    def self.epoch(root, ref = "HEAD")
      out = IO.popen(["git", "-C", root, "log", "-1", "--format=%ct", ref], &:read).to_s.strip
      raise Error, "no commit time for #{ref}" unless out.match?(/\A\d+\z/)

      out.to_i
    end

    def self.build(root, name, version, out_dir, epoch:)
      out = File.join(out_dir, Releaser.gem_file(name, version))
      ok = system({ "SOURCE_DATE_EPOCH" => epoch.to_s }, "gem", "build", "#{name}.gemspec", "--output", out,
                  chdir: Releaser.gem_dir(name, root), out: File::NULL)
      raise Error, "gem build failed for #{name}" unless ok

      out
    end

    def self.all(root, version, out_dir, epoch:)
      FileUtils.mkdir_p(out_dir)
      GEMS.map { |name| build(root, name, version, out_dir, epoch: epoch) }
    end

    def self.checksums(files) = files.to_h { |f| [File.basename(f), Digest::SHA256.file(f).hexdigest] }

    def self.umbrella_files(root)
      spec = Gem::Specification.load(File.join(root, "poetry.gemspec"))
      raise Error, "poetry.gemspec did not load" unless spec

      spec.files
    end

    # The umbrella ships lib/ and the three root documents, nothing below the root.
    def self.check_umbrella!(root)
      strays = umbrella_files(root).reject { |f| f.start_with?("lib/") || UMBRELLA_DOCS.include?(f) }
      raise Error, "the umbrella gem would ship #{strays.join(', ')}" unless strays.empty?

      true
    end
  end

  # sigstore bundles, signed with the workflow's OIDC identity and verified
  # against it before anything is pushed.
  module Sign
    def self.bundle_for(gem_path) = "#{gem_path}.sigstore.json"

    def self.identity(repository:, ref:, workflow: ".github/workflows/release.yml")
      "https://github.com/#{repository}/#{workflow}@#{ref}"
    end

    def self.sign(gem_path)
      ok = system("sigstore-cli", "sign", gem_path, "--bundle", bundle_for(gem_path))
      raise Error, "signing failed for #{File.basename(gem_path)}" unless ok

      bundle_for(gem_path)
    end

    def self.verify(gem_path, identity:, issuer: ISSUER)
      ok = system("sigstore-cli", "verify", "--bundle", bundle_for(gem_path), "--certificate-identity", identity,
                  "--certificate-oidc-issuer", issuer, gem_path)
      raise Error, "verification failed for #{File.basename(gem_path)}" unless ok

      true
    end
  end

  # Idempotent pushes: a version RubyGems already holds is skipped when the
  # checksum matches and stops the release when it does not.
  module Push
    def self.decision(remote_sha, local_sha)
      return :push if remote_sha.nil?

      remote_sha == local_sha ? :skip : :abort
    end

    # The CDN in front of the API caches a not-found for a minute, so the
    # lookup carries a fresh query string every time.
    def self.remote_sha(name, version)
      uri = URI("https://rubygems.org/api/v2/rubygems/#{name}/versions/#{version}.json?fresh=#{Time.now.to_f}")
      response = Net::HTTP.get_response(uri)
      case response
      when Net::HTTPNotFound then nil
      when Net::HTTPSuccess then JSON.parse(response.body)["sha"]
      else raise Error, "RubyGems answered #{response.code} for #{name} #{version}"
      end
    end

    REPUSH_REFUSED = /Repushing of gem versions is not allowed/

    # Pushes, and returns :pushed; when RubyGems refuses a repush the version
    # is already there, so the checksum is fetched again (the API may lag)
    # and a match is :skip while a mismatch stops the release.
    def self.push(gem_path, attestation:, name: nil, version: nil, local_sha: nil, fetch: nil)
      output, status = Open3.capture2e("gem", "push", gem_path, "--attestation", attestation)
      $stdout.print output
      return :pushed if status.success?
      raise Error, "push failed for #{File.basename(gem_path)}" unless output.match?(REPUSH_REFUSED) && fetch

      settle(name, version, local_sha, fetch: fetch)
    end

    # After a refused repush: the checksum RubyGems holds, asked for again a
    # few times because the API can lag the push by a minute.
    def self.settle(name, version, local_sha, fetch:, attempts: 6, pause: 10)
      remote = nil
      attempts.times do
        remote = fetch.call
        break if remote

        sleep pause
      end
      raise Error, "#{name} #{version} refused as a repush but never appears in the API" if remote.nil?
      raise Error, "#{name} #{version} is on RubyGems with a different checksum; stop and look" unless remote == local_sha

      :skip
    end

    def self.all(root, version, out_dir, log: $stdout)
      GEMS.each do |name|
        gem_path = File.join(out_dir, Releaser.gem_file(name, version))
        local_sha = Digest::SHA256.file(gem_path).hexdigest
        case decision(remote_sha(name, version), local_sha)
        when :push
          log.puts "push #{name} #{version}"
          outcome = push(gem_path, attestation: Sign.bundle_for(gem_path), name: name, version: version,
                         local_sha: local_sha, fetch: -> { remote_sha(name, version) })
          log.puts "skip #{name} #{version}: RubyGems already held it with this checksum" if outcome == :skip
        when :skip
          log.puts "skip #{name} #{version}: already on RubyGems with this checksum"
        when :abort
          raise Error, "#{name} #{version} is on RubyGems with a different checksum; stop and look"
        end
      end
      root
    end

    def self.await(version)
      ok = system("rubygems-await", *GEMS.map { |name| "#{name}:#{version}" })
      raise Error, "rubygems-await failed" unless ok

      true
    end
  end

  # The annotated tag and the draft release the train creates; the tag check
  # the workflow repeats before it builds anything.
  module Tag
    def self.name(version) = "v#{version}"

    def self.verify(root, ref, version, main: "origin/main")
      raise Error, "#{ref.inspect} is not the tag for VERSION #{version} (expected #{name(version)})" unless ref == name(version)

      mismatches = Versions.mismatches(root, version)
      raise Error, "version files disagree with VERSION:\n  #{mismatches.join("\n  ")}" unless mismatches.empty?
      raise Error, "#{ref} is not an ancestor of #{main}" unless system("git", "-C", root, "merge-base", "--is-ancestor", ref, main)

      true
    end

    def self.create(root, version)
      tag = name(version)
      exists = system("git", "-C", root, "rev-parse", "-q", "--verify", "refs/tags/#{tag}", out: File::NULL, err: File::NULL)
      raise Error, "#{tag} already exists" if exists

      system("git", "-C", root, "tag", "-a", tag, "-m", "Version #{version}", exception: true)
      system("git", "-C", root, "push", "origin", tag, exception: true)
      tag
    end

    def self.draft_release(root, version, notes_path)
      system("gh", "release", "create", name(version), "--draft", "--verify-tag", "--title", "Poetry #{version}",
             "--notes-file", notes_path, chdir: root, exception: true)
      true
    end
  end
end
