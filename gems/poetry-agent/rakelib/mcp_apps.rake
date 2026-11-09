# frozen_string_literal: true

require "digest"
require "fileutils"

# The MCP Apps ground truth: the stable specification and the generated
# wire schema from the extension's repository, vendored with a manifest so
# `rake` tells when the copies drift (the a2ui tasks' shape). The tests
# hold Poetry's resource metadata, tool metadata and results to the schema.
namespace :mcp_apps do
  upstream = File.expand_path("../test/fixtures/mcp_apps/upstream", __dir__)
  files = %w[specification/2026-01-26/apps.mdx src/generated/schema.json]

  manifest = lambda do |root, list|
    list.map { |file| "#{Digest::SHA256.file(File.join(root, file)).hexdigest}  #{file}" }.join("\n") << "\n"
  end

  desc "Vendor the MCP Apps specification and wire schema from a checkout (EXT_APPS=path)"
  task :vendor do
    source = ENV.fetch("EXT_APPS") { abort "mcp_apps:vendor: set EXT_APPS to an ext-apps checkout" }
    commit = `git -C #{source} rev-parse --short=9 HEAD`.strip
    abort "mcp_apps:vendor: #{source} is not a git checkout" if commit.empty?

    FileUtils.rm_rf(upstream)
    files.each do |file|
      FileUtils.mkdir_p(File.join(upstream, File.dirname(file)))
      FileUtils.cp(File.join(source, file), File.join(upstream, file))
    end
    FileUtils.cp(File.join(source, "LICENSE"), File.join(upstream, "LICENSE"))
    File.write(File.join(upstream, "SHA256SUMS"), manifest.call(upstream, files))
    File.write(File.join(upstream, "COMMIT"), "#{commit}\n")
    puts "mcp_apps:vendor: #{files.size} files from #{commit}"
  end

  desc "Fail when a vendored MCP Apps file differs from its manifest"
  task :verify do
    listed = File.readlines(File.join(upstream, "SHA256SUMS"), chomp: true).map { |line| line.split("  ", 2) }
    stale = listed.reject do |sum, file|
      path = File.join(upstream, file)
      File.exist?(path) && Digest::SHA256.file(path).hexdigest == sum
    end
    if stale.any?
      abort "mcp_apps:verify: #{stale.map(&:last).join(", ")} differ from SHA256SUMS - run rake mcp_apps:vendor"
    end

    commit = File.read(File.join(upstream, "COMMIT")).strip
    puts "mcp_apps:verify: #{listed.size} vendored files match SHA256SUMS at #{commit}"
  end
end
