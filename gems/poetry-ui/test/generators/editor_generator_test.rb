# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "yaml"
require "generators/poetry/editor/editor_generator"

module Poetry
  # poetry:editor - wire the MCP server + registry-driven snippets into the
  # editors a Rails team uses. MCP writes are upserts; snippets are generated
  # from the committed registry so they can't drift from the shipped catalog.
  class EditorGeneratorTest < Rails::Generators::TestCase
    tests Poetry::EditorGenerator
    destination File.expand_path("../tmp/editor-dest", __dir__)
    setup :prepare_destination

    def read_json(relative)
      JSON.parse(File.read(File.join(destination_root, relative)))
    end

    def test_creates_per_editor_mcp_configs_with_the_right_shapes
      run_generator

      poetry = { "command" => "bundle", "args" => %w[exec poetry-agent] }

      assert_equal poetry, read_json(".mcp.json").dig("mcpServers", "poetry")        # Claude Code
      assert_equal poetry, read_json(".cursor/mcp.json").dig("mcpServers", "poetry") # Cursor

      vscode = read_json(".vscode/mcp.json").dig("servers", "poetry")                # VS Code

      assert_equal "stdio", vscode["type"]
      assert_equal "bundle", vscode["command"]
    end

    def test_writes_a_herb_config_unless_the_app_has_one
      run_generator
      config = YAML.safe_load_file(File.join(destination_root, ".herb.yml"))

      assert_equal "actionview", config["framework"]
      assert_match(/\A\d+\.\d+\.\d+\z/, config["version"].to_s, "the linter version is pinned")
      assert_equal({ "enabled" => false }, config.dig("linter", "rules", "erb-no-unused-expressions"))
      assert_equal({ "enabled" => false }, config.dig("linter", "rules", "actionview-no-silent-helper"))

      File.write(File.join(destination_root, ".herb.yml"), "version: 0.9.0\n")
      output = run_generator

      assert_equal "version: 0.9.0\n", File.read(File.join(destination_root, ".herb.yml")),
                   "an existing config is never clobbered"
      assert_match(/skip\s+\.herb\.yml exists/, output)
    end

    def test_lists_poetrys_controllers_for_stimulus_lsp_and_keeps_an_existing_ignore_list
      run_generator
      config = read_json(".stimulus-lsp/config.json")
      identifiers = config.dig("options", "ignoredControllerIdentifiers")

      assert_equal Poetry::Core::Stimulus::Manifest.catalog.keys.sort, identifiers
      assert_includes identifiers, "poetry--core--dialog"
      assert_equal [], config.dig("options", "ignoredAttributes")
      assert_match(/\A\d+\.\d+\.\d+\z/, config["version"])

      existing = { "version" => "1.0.0", "createdAt" => "2026-01-01T00:00:00.000Z",
                   "updatedAt" => "2026-01-01T00:00:00.000Z",
                   "options" => { "ignoredControllerIdentifiers" => ["legacy"],
                                  "ignoredAttributes" => ["data-turbo"] } }
      File.write(File.join(destination_root, ".stimulus-lsp/config.json"), JSON.pretty_generate(existing))
      output = run_generator
      merged = read_json(".stimulus-lsp/config.json")

      assert_includes merged.dig("options", "ignoredControllerIdentifiers"), "legacy"
      assert_includes merged.dig("options", "ignoredControllerIdentifiers"), "poetry--core--dialog"
      assert_equal ["data-turbo"], merged.dig("options", "ignoredAttributes")
      assert_equal "1.0.0", merged["version"], "the LSP owns the version field"
      assert_match(%r{update\s+\.stimulus-lsp/config\.json}, output)
      assert_match(%r{identical\s+\.stimulus-lsp/config\.json}, run_generator, "a complete list is left alone")
    end

    def test_generates_snippets_from_the_committed_registry
      run_generator
      snippets = read_json(".vscode/poetry.code-snippets")

      button = snippets.fetch("poetry button")

      assert_equal "poetry_button", button["prefix"]
      assert_includes button["body"].join, "variant: :${1|", "the primary enum becomes a choice tab-stop"
      assert_includes button["body"].join, "secondary", "only real variant values are offered"

      # a slotted component composes via a `do |c|` block; an atom is inline
      assert_kind_of Array, snippets.dig("poetry dialog", "body")
      assert_kind_of String, snippets.dig("poetry separator", "body")
      assert_includes snippets.dig("poetry separator", "body"), "orientation: :${1|horizontal,vertical|}"
    end

    def test_upserts_into_an_existing_config_preserving_other_servers
      File.write(File.join(destination_root, ".mcp.json"),
                 JSON.generate("mcpServers" => { "other" => { "command" => "x" } }))

      run_generator

      servers = read_json(".mcp.json").fetch("mcpServers")

      assert servers.key?("other"), "existing servers are preserved"
      assert servers.key?("poetry"), "the poetry server is added alongside"
    end

    def test_leaves_an_already_configured_poetry_server_untouched
      File.write(File.join(destination_root, ".mcp.json"),
                 JSON.generate("mcpServers" => { "poetry" => { "command" => "custom" } }))

      output = run_generator

      assert_equal "custom", read_json(".mcp.json").dig("mcpServers", "poetry", "command")
      assert_match(/identical/, output)
    end

    def test_reports_but_never_clobbers_a_jsonc_config_it_cannot_parse
      FileUtils.mkdir_p(File.join(destination_root, ".vscode"))
      jsonc = "{\n  // VS Code allows comments\n  \"servers\": {}\n}\n"
      File.write(File.join(destination_root, ".vscode/mcp.json"), jsonc)

      output = run_generator

      assert_equal jsonc, File.read(File.join(destination_root, ".vscode/mcp.json")), "left byte-for-byte intact"
      assert_match(/isn't plain JSON/, output)
    end

    def test_prints_paste_blocks_for_ide_managed_editors
      output = run_generator

      assert_match(/Zed/, output)
      assert_match(/Windsurf/, output)
      assert_match(/RubyMine/, output)
    end
  end
end
