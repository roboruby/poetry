# frozen_string_literal: true

require "digest"
require "json"

module Poetry
  module Agent
    # The report-only upstream watch for the protocols poetry-agent
    # implements: a committed manifest pins what the AG-UI repository
    # looked like when Poetry last synced (its 1.0 schema, fixtures and
    # conformance corpus, the two middlewares' sources and the wire
    # constants Poetry's own code mirrors), and `rake upstream:watch` diffs
    # a current checkout against it. A2UI and MCP Apps are already pinned
    # by their vendoring manifests (`SHA256SUMS` and `COMMIT` under
    # `test/fixtures`), so the watch reads those and says which vendored
    # file moved upstream; the `mcp` gem is pinned by version. The report
    # is an alarm, not a gate: it names what changed, and a person decides
    # whether to re-vendor, re-extract or re-read.
    #
    # @api private
    module UpstreamWatch
      module_function

      # The AG-UI material the manifest digests, relative to the checkout:
      # files one by one, directories as a tree, and the tokens Poetry's
      # wire constants depend on, each looked for in a named source file.
      AG_UI = {
        repo: "https://github.com/ag-ui-protocol/ag-ui",
        files: %w[
          spec/1.0/schema.json
          spec/1.0/proto-freeze.txt
          spec/1.0/conformance/streams/MANIFEST.txt
          middlewares/mcp-apps-middleware/src/index.ts
          middlewares/a2ui-middleware/src/index.ts
          middlewares/a2ui-middleware/src/types.ts
          sdks/typescript/packages/core/package.json
        ],
        directories: %w[
          spec/1.0/fixtures
          spec/1.0/conformance/streams
          sdks/typescript/packages/client/src
        ],
        tokens: {
          "middlewares/mcp-apps-middleware/src/index.ts" =>
            ['MCPAppsActivityType = "mcp-apps"', "serverHash", "serverId", "resourceUri", "toolInput"],
          "middlewares/a2ui-middleware/src/index.ts" =>
            ['A2UIActivityType = "a2ui-surface"', "a2ui_operations", "a2ui-surface-${key}"],
          "middlewares/a2ui-middleware/src/types.ts" =>
            %w[a2uiAction userAction surfaceId sourceComponentId createSurface updateComponents updateDataModel
               deleteSurface]
        }
      }.freeze

      # The upstreams pinned by a vendoring manifest: the sums file names the
      # files and their digests, the commit file the checkout they came from.
      VENDORED = {
        "A2UI" => { repo: "https://github.com/google/A2UI", sums: "test/fixtures/a2ui/upstream/SHA256SUMS",
                    commit: "test/fixtures/a2ui/upstream/COMMIT" },
        "ext-apps" => { repo: "https://github.com/modelcontextprotocol/ext-apps",
                        sums: "test/fixtures/mcp_apps/upstream/SHA256SUMS",
                        commit: "test/fixtures/mcp_apps/upstream/COMMIT" }
      }.freeze

      # The checkout directory each upstream is expected under.
      CHECKOUTS = { "ag-ui" => "ag-ui", "A2UI" => "A2UI", "ext-apps" => "ext-apps" }.freeze

      # A file's digest, or nil when it is missing.
      #
      # @param path [String] the file
      # @return [String, nil]
      def file_digest(path)
        File.file?(path) ? Digest::SHA256.file(path).hexdigest : nil
      end

      # A directory's digest: every file under it, by sorted relative path
      # and content, so a file added, removed or changed moves the digest.
      #
      # @param path [String] the directory
      # @return [String, nil] nil when the directory is missing
      def directory_digest(path)
        return nil unless File.directory?(path)

        entries = Dir.glob("**/*", File::FNM_DOTMATCH, base: path)
        entries = entries.select { |entry| File.file?(File.join(path, entry)) }.sort
        digest = Digest::SHA256.new
        entries.each do |entry|
          digest << entry << "\0" << Digest::SHA256.file(File.join(path, entry)).hexdigest << "\n"
        end
        digest.hexdigest
      end

      # The tokens found in a file, in the order asked for.
      #
      # @param path [String] the file
      # @param tokens [Array<String>] what to look for
      # @return [Array<String>] the ones present; none when the file is missing
      def tokens_present(path, tokens)
        return [] unless File.file?(path)

        source = File.read(path)
        tokens.select { |token| source.include?(token) }
      end

      # The AG-UI side of a manifest, built over a checkout.
      #
      # @param root [String] the ag-ui checkout
      # @param pin [String, nil] the checkout's commit, recorded on a pin
      # @return [Hash] `pin`, `core_version`, `files`, `directories` and `tokens`
      def build_ag_ui(root, pin: nil)
        core = File.join(root, "sdks/typescript/packages/core/package.json")
        version = File.file?(core) ? JSON.parse(File.read(core))["version"] : nil
        {
          "pin" => pin, "core_version" => version,
          "files" => AG_UI[:files].to_h { |file| [file, file_digest(File.join(root, file))] },
          "directories" => AG_UI[:directories].to_h { |dir| [dir, directory_digest(File.join(root, dir))] },
          "tokens" => AG_UI[:tokens].to_h { |file, tokens| [file, tokens_present(File.join(root, file), tokens)] }
        }
      end

      # The whole manifest: AG-UI over its checkout, the gem by version.
      #
      # @param root [String] the ag-ui checkout
      # @param pin [String] the checkout's commit
      # @param generated_at [String] the date
      # @param mcp_version [String] the `mcp` gem's version
      # @return [Hash]
      def build_manifest(root, pin:, generated_at:, mcp_version:)
        { "generated_at" => generated_at, "ag-ui" => build_ag_ui(root, pin: pin),
          "mcp" => { "version" => mcp_version } }
      end

      # What moved in AG-UI between a pinned manifest and a current build.
      #
      # @param pinned [Hash] the manifest's `ag-ui`
      # @param current [Hash] a fresh {build_ag_ui}
      # @return [Hash] `files`, `directories` (the paths that changed or vanished), `tokens` (by file, the ones
      #   no longer found), `core_version` (`[pinned, current]` when they differ)
      def diff_ag_ui(pinned, current)
        changed = lambda do |kind|
          was = pinned.fetch(kind, {})
          now = current.fetch(kind, {})
          was.keys.reject { |path| was[path] == now[path] }
        end
        tokens = AG_UI[:tokens].each_with_object({}) do |(file, expected), gone|
          missing = expected - current.dig("tokens", file).to_a
          gone[file] = missing if missing.any?
        end
        versions = [pinned["core_version"], current["core_version"]]
        { "files" => changed.call("files"), "directories" => changed.call("directories"), "tokens" => tokens,
          "core_version" => (versions if versions.uniq.size > 1) }
      end

      # What moved in a vendored upstream: the sums file's entries hashed
      # again over the checkout.
      #
      # @param sums_path [String] the vendoring manifest
      # @param root [String] the upstream checkout
      # @return [Hash] `changed` and `missing`, as relative paths
      def diff_vendored(sums_path, root)
        listed = File.readlines(sums_path, chomp: true).map { |line| line.split("  ", 2) }
        missing = listed.map(&:last).reject { |file| File.file?(File.join(root, file)) }
        changed = listed.reject do |sum, file|
          missing.include?(file) || file_digest(File.join(root, file)) == sum
        end
        { "changed" => changed.map(&:last), "missing" => missing }
      end

      # Whether a diff reports anything.
      #
      # @param diff [Hash] a {diff_ag_ui} or {diff_vendored} result
      # @return [Boolean]
      def drift?(diff)
        diff.values.any? do |value|
          case value
          when Hash, Array then value.any?
          else !value.nil?
          end
        end
      end

      # The diff entries that read as a pair, pinned and current.
      PAIRS = %w[core_version installed latest core_latest].freeze

      # The report for one upstream, a few lines.
      #
      # @param name [String] the upstream
      # @param heading [String] the pin and the checkout, as the caller words it
      # @param diff [Hash] its diff
      # @return [String]
      def format_report(name, heading, diff)
        lines = ["#{name}: #{heading}"]
        return (lines << "  no drift").join("\n") unless drift?(diff)

        diff.each do |kind, value|
          next if value.nil? || (value.respond_to?(:empty?) && value.empty?)

          if PAIRS.include?(kind) then lines << "  #{kind}: #{value.join(" -> ")}"
          elsif value.is_a?(Hash) then value.each do |file, missing|
            lines << "  #{kind} gone from #{file}: #{missing.join(", ")}"
          end
          else lines << "  #{kind}: #{value.join(", ")}"
          end
        end
        lines.join("\n")
      end
    end
  end
end
