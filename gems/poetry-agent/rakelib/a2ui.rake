# frozen_string_literal: true

require "digest"
require "fileutils"

# The A2UI material poetry-agent is tested against, vendored from an A2UI
# checkout in upstream's own layout (test/fixtures/a2ui/upstream), so the
# conformance suites' relative catalog paths resolve. Test-only: test/ never
# ships. A re-pin vendors a newer checkout, then the conformance suite says
# what changed.
namespace :a2ui do
  upstream = File.expand_path("../test/fixtures/a2ui/upstream", __dir__)
  suites = %w[actions composition_constraints data_context data_deletion data_model data_model_pointers expressions
              functions index_function message_processor_v0_9 message_processor_v1_0 multi_catalog reserved_keys
              rpc_functions validation_result validator_v0_9 validator_v1_0]
  catalogs = %w[catalogs/basic/v1/catalog.json specification/v0_9/catalogs/basic/catalog.json
                specification/v0_9_1/catalogs/basic/catalog.json
                conformance/test_data/catalogs/custom_catalog_v1_0.json]
  examples = %w[catalogs/basic/v1/examples specification/v0_9/catalogs/basic/examples]
  schemas = %w[specification/v0_9/json specification/v1_0/json]

  # The manifest: one "sha256  path" line per vendored file.
  manifest = lambda do |root, files|
    files.map { |file| "#{Digest::SHA256.file(File.join(root, file)).hexdigest}  #{file}" }.join("\n") << "\n"
  end

  desc "Vendor A2UI's conformance suites, catalogs and examples from a checkout (A2UI=path)"
  task :vendor do
    source = ENV.fetch("A2UI") { abort "a2ui:vendor: set A2UI to an A2UI checkout" }
    commit = `git -C #{source} rev-parse --short=9 HEAD`.strip
    abort "a2ui:vendor: #{source} is not a git checkout" if commit.empty?

    files = suites.map { |suite| "conformance/core/#{suite}.yaml" } + catalogs
    files += Dir.chdir(source) { (examples + schemas).flat_map { |dir| Dir["#{dir}/*.json"] } }.sort
    FileUtils.rm_rf(upstream)
    files.each do |file|
      FileUtils.mkdir_p(File.join(upstream, File.dirname(file)))
      FileUtils.cp(File.join(source, file), File.join(upstream, file))
    end
    FileUtils.cp(File.join(source, "LICENSE"), File.join(upstream, "LICENSE"))
    File.write(File.join(upstream, "SHA256SUMS"), manifest.call(upstream, files))
    File.write(File.join(upstream, "COMMIT"), "#{commit}\n")
    puts "a2ui:vendor: #{files.size} files from #{commit}"
  end

  desc "Fail when a vendored A2UI file differs from its manifest"
  task :verify do
    listed = File.readlines(File.join(upstream, "SHA256SUMS"), chomp: true).map { |line| line.split("  ", 2) }
    stale = listed.reject do |sum, file|
      path = File.join(upstream, file)
      File.exist?(path) && Digest::SHA256.file(path).hexdigest == sum
    end
    abort "a2ui:verify: #{stale.map(&:last).join(", ")} differ from SHA256SUMS - run rake a2ui:vendor" if stale.any?

    commit = File.read(File.join(upstream, "COMMIT")).strip
    puts "a2ui:verify: #{listed.size} vendored files match SHA256SUMS at #{commit}"
  end
end
