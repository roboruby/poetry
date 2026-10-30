# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"
require "poetry/agent/upstream_watch"

module Poetry
  module Agent
    # The upstream watch over a fake checkout: the manifest it builds, the
    # drift it reports (a changed file, a changed tree, a vanished token, a
    # moved version), the vendored manifests read against a checkout, and
    # the report's words.
    class UpstreamWatchTest < Minitest::Test
      # A checkout with every watched path present and the tokens in place.
      def checkout(dir)
        write = lambda do |path, content|
          full = File.join(dir, path)
          FileUtils.mkdir_p(File.dirname(full))
          File.write(full, content)
        end
        UpstreamWatch::AG_UI[:files].each { |file| write.call(file, "#{file}\n") }
        write.call("sdks/typescript/packages/core/package.json",
                   JSON.generate({ "name" => "@ag-ui/core", "version" => "1.0.3" }))
        UpstreamWatch::AG_UI[:directories].each { |held| write.call("#{held}/one.json", "{}") }
        UpstreamWatch::AG_UI[:tokens].each { |file, tokens| write.call(file, "#{tokens.join("\n")}\n") }
        dir
      end

      def test_the_manifest_digests_files_and_trees_and_finds_the_tokens
        Dir.mktmpdir do |dir|
          checkout(dir)
          manifest = UpstreamWatch.build_manifest(dir, pin: "abc123456", generated_at: "2026-10-30",
                                                       mcp_version: "1.8.2")
          ag_ui = manifest["ag-ui"]

          assert_equal "abc123456", ag_ui["pin"]
          assert_equal "1.0.3", ag_ui["core_version"]
          assert_equal UpstreamWatch::AG_UI[:files].sort, ag_ui["files"].keys.sort
          assert(ag_ui["files"].values.all? { |sum| sum.match?(/\A\h{64}\z/) })
          assert(ag_ui["directories"].values.all? { |sum| sum.match?(/\A\h{64}\z/) })
          UpstreamWatch::AG_UI[:tokens].each { |file, tokens| assert_equal tokens, ag_ui["tokens"][file] }
          assert_equal({ "version" => "1.8.2" }, manifest["mcp"])
          refute UpstreamWatch.drift?(UpstreamWatch.diff_ag_ui(ag_ui, UpstreamWatch.build_ag_ui(dir)))
        end
      end

      def test_a_changed_file_a_changed_tree_a_vanished_token_and_a_moved_version_are_reported
        Dir.mktmpdir do |dir|
          checkout(dir)
          pinned = UpstreamWatch.build_ag_ui(dir, pin: "abc123456")
          File.write(File.join(dir, "spec/1.0/schema.json"), "{\"changed\": true}")
          File.write(File.join(dir, "spec/1.0/fixtures/two.json"), "{}")
          index = File.join(dir, "middlewares/mcp-apps-middleware/src/index.ts")
          File.write(index, File.read(index).sub('MCPAppsActivityType = "mcp-apps"', 'MCPAppsActivityType = "mcp-app"'))
          File.write(File.join(dir, "sdks/typescript/packages/core/package.json"),
                     JSON.generate({ "name" => "@ag-ui/core", "version" => "1.1.0" }))
          diff = UpstreamWatch.diff_ag_ui(pinned, UpstreamWatch.build_ag_ui(dir))

          assert UpstreamWatch.drift?(diff)
          assert_equal %w[spec/1.0/schema.json sdks/typescript/packages/core/package.json
                          middlewares/mcp-apps-middleware/src/index.ts].sort, diff["files"].sort
          assert_equal ["spec/1.0/fixtures"], diff["directories"]
          assert_equal({ "middlewares/mcp-apps-middleware/src/index.ts" => ['MCPAppsActivityType = "mcp-apps"'] },
                       diff["tokens"])
          assert_equal %w[1.0.3 1.1.0], diff["core_version"]
          report = UpstreamWatch.format_report("ag-ui", "pin abc123456 vs checkout def", diff)

          assert_includes report, "files: "
          assert_includes report, "tokens gone from middlewares/mcp-apps-middleware/src/index.ts: MCPAppsActivityType"
          assert_includes report, "core_version: 1.0.3 -> 1.1.0"
          assert_equal "ag-ui: same\n  no drift",
                       UpstreamWatch.format_report("ag-ui", "same", UpstreamWatch.diff_ag_ui(pinned, pinned))
        end
      end

      def test_a_vendored_manifest_is_read_against_a_checkout
        Dir.mktmpdir do |dir|
          root = File.join(dir, "checkout")
          FileUtils.mkdir_p(File.join(root, "spec"))
          File.write(File.join(root, "spec/a.json"), "a")
          File.write(File.join(root, "spec/b.json"), "b")
          sums = File.join(dir, "SHA256SUMS")
          entries = { "a" => "spec/a.json", "old" => "spec/b.json", "c" => "spec/c.json" }
          File.write(sums, entries.map { |content, file| "#{Digest::SHA256.hexdigest(content)}  #{file}\n" }.join)
          diff = UpstreamWatch.diff_vendored(sums, root)

          assert_equal({ "changed" => ["spec/b.json"], "missing" => ["spec/c.json"] }, diff)
          assert UpstreamWatch.drift?(diff)
          assert_includes UpstreamWatch.format_report("A2UI", "vendored at x vs y", diff), "missing: spec/c.json"
        end
      end

      def test_poetry_s_wire_constants_are_the_ones_the_watch_looks_for
        tokens = UpstreamWatch::AG_UI[:tokens]

        assert_includes tokens["middlewares/mcp-apps-middleware/src/index.ts"], %(MCPAppsActivityType = "#{Apps::Activity::TYPE}")
        activity = Apps::Activity.from({ "result" => { "content" => [{ "type" => "text", "text" => "plans" }] },
                                         "resourceUri" => "ui://shop/plans", "serverId" => "shop", "serverHash" => "h1",
                                         "toolInput" => { "team_size" => 8 } })

        assert_equal ["ui://shop/plans", "shop", "h1", { "team_size" => 8 }],
                     [activity.resource_uri, activity.server_id, activity.server_hash, activity.tool_input]
        %w[serverHash serverId resourceUri toolInput].each do |key|
          assert_includes tokens["middlewares/mcp-apps-middleware/src/index.ts"], key
        end
        surface = Struct.new(:data, :send_data_model).new({ "count" => 1 }, true)
        action = A2UI::Session::Action.new(message: { "version" => "1.0", "action" => { "name" => "pick" } },
                                           surface: surface)

        assert_equal({ "a2uiAction" => { "userAction" => { "name" => "pick" }, "dataModel" => { "count" => 1 } } },
                     action.forwarded_props)
        %w[a2uiAction userAction].each { |key| assert_includes tokens["middlewares/a2ui-middleware/src/types.ts"], key }
        assert_includes tokens["middlewares/a2ui-middleware/src/index.ts"], 'A2UIActivityType = "a2ui-surface"'
      end
    end
  end
end
