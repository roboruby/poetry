# frozen_string_literal: true

require "digest"
require "json"

module Poetry
  module Agent
    # The report-only upstream watch for the protocols poetry-agent
    # implements: a committed manifest pins what the AG-UI and WebMCP
    # repositories looked like when Poetry last synced (AG-UI's 1.0
    # schema, fixtures and conformance corpus, the two middlewares'
    # sources and the wire constants Poetry's own code mirrors; WebMCP's
    # specification source, its explainers, its implementation status and
    # the IDL names the adapter and the tool DSL depend on), and `rake
    # upstream:watch` diffs current checkouts against it. A2UI and MCP
    # Apps are already pinned by their vendoring manifests (`SHA256SUMS`
    # and `COMMIT` under `test/fixtures`), so the watch reads those and
    # says which vendored file moved upstream; the `mcp` gem is pinned by
    # version. The report is an alarm, not a gate: it names what changed,
    # and a person decides whether to re-vendor, re-extract or re-read.
    #
    # @api private
    module UpstreamWatch
      module_function

      # The AG-UI material the manifest digests, relative to the checkout:
      # files one by one, directories as a tree, the tokens Poetry's wire
      # constants depend on, each looked for in a named source file, and
      # the package whose version the manifest records.
      AG_UI = {
        repo: "https://github.com/ag-ui-protocol/ag-ui",
        version_file: "sdks/typescript/packages/core/package.json",
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

      # The WebMCP specification repository: the spec source, the two
      # explainers the declarative form and the GET-only autosubmit rule
      # lean on, the implementation status, and the IDL names the
      # `document.modelContext` adapter and the tool DSL's annotations
      # depend on.
      WEBMCP = {
        repo: "https://github.com/webmachinelearning/webmcp",
        files: %w[index.bs declarative-api-explainer.md continuations-explainer.md implementation-status.md],
        directories: [],
        tokens: {
          "index.bs" =>
            ["partial interface Document", "readonly attribute ModelContext modelContext",
             "interface ModelContext : EventTarget", "registerTool(", "getTools(", "executeTool(",
             "ontoolchange", "ontoolactivated", "ontoolcancel", "readonly attribute DOMString toolName",
             "boolean readOnlyHint", "boolean untrustedContentHint", "boolean consequentialHint",
             "boolean debugging"],
          "declarative-api-explainer.md" =>
            %w[toolname tooldescription toolautosubmit toolparamdescription :tool-form-active :tool-submit-active
               agentInvoked respondWith]
        }
      }.freeze

      # The upstreams watched as a tree over a checkout, by manifest key.
      TREES = { "ag-ui" => AG_UI, "webmcp" => WEBMCP }.freeze

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
      CHECKOUTS = { "ag-ui" => "ag-ui", "webmcp" => "webmcp", "A2UI" => "A2UI", "ext-apps" => "ext-apps" }.freeze

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

      # One tree's side of a manifest, built over its checkout.
      #
      # @param config [Hash] one of {TREES}
      # @param root [String] the checkout
      # @param pin [String, nil] the checkout's commit, recorded on a pin
      # @return [Hash] `pin`, `core_version` (when the tree names a version file), `files`, `directories` and
      #   `tokens`
      def build_tree(config, root, pin: nil)
        tree = { "pin" => pin }
        if (version_file = config[:version_file])
          path = File.join(root, version_file)
          tree["core_version"] = File.file?(path) ? JSON.parse(File.read(path))["version"] : nil
        end
        tree.merge(
          "files" => config[:files].to_h { |file| [file, file_digest(File.join(root, file))] },
          "directories" => config[:directories].to_h { |dir| [dir, directory_digest(File.join(root, dir))] },
          "tokens" => config[:tokens].to_h { |file, tokens| [file, tokens_present(File.join(root, file), tokens)] }
        )
      end

      # The AG-UI side of a manifest, built over a checkout.
      #
      # @param root [String] the ag-ui checkout
      # @param pin [String, nil] the checkout's commit, recorded on a pin
      # @return [Hash] `pin`, `core_version`, `files`, `directories` and `tokens`
      def build_ag_ui(root, pin: nil)
        build_tree(AG_UI, root, pin: pin)
      end

      # The whole manifest: AG-UI and WebMCP over their checkouts, the gem
      # by version.
      #
      # @param root [String] the ag-ui checkout
      # @param pin [String] the ag-ui checkout's commit
      # @param generated_at [String] the date
      # @param mcp_version [String] the `mcp` gem's version
      # @param webmcp_root [String, nil] the webmcp checkout; without it the manifest carries no WebMCP section
      # @param webmcp_pin [String, nil] the webmcp checkout's commit
      # @return [Hash]
      def build_manifest(root, pin:, generated_at:, mcp_version:, webmcp_root: nil, webmcp_pin: nil)
        manifest = { "generated_at" => generated_at, "ag-ui" => build_ag_ui(root, pin: pin) }
        manifest["webmcp"] = build_tree(WEBMCP, webmcp_root, pin: webmcp_pin) if webmcp_root
        manifest.merge("mcp" => { "version" => mcp_version })
      end

      # What moved in a tree between its pinned manifest and a current build.
      #
      # @param config [Hash] one of {TREES}
      # @param pinned [Hash] the manifest's section for it
      # @param current [Hash] a fresh {build_tree}
      # @return [Hash] `files`, `directories` (the paths that changed or vanished), `tokens` (by file, the ones
      #   no longer found), `core_version` (`[pinned, current]` when they differ)
      def diff_tree(config, pinned, current)
        changed = lambda do |kind|
          was = pinned.fetch(kind, {})
          now = current.fetch(kind, {})
          was.keys.reject { |path| was[path] == now[path] }
        end
        tokens = config[:tokens].each_with_object({}) do |(file, expected), gone|
          missing = expected - current.dig("tokens", file).to_a
          gone[file] = missing if missing.any?
        end
        versions = [pinned["core_version"], current["core_version"]]
        { "files" => changed.call("files"), "directories" => changed.call("directories"), "tokens" => tokens,
          "core_version" => (versions if versions.uniq.size > 1) }
      end

      # What moved in AG-UI between a pinned manifest and a current build.
      #
      # @param pinned [Hash] the manifest's `ag-ui`
      # @param current [Hash] a fresh {build_ag_ui}
      # @return [Hash] as {diff_tree} answers
      def diff_ag_ui(pinned, current)
        diff_tree(AG_UI, pinned, current)
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
      # @param diff [Hash] a {diff_tree} or {diff_vendored} result
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
