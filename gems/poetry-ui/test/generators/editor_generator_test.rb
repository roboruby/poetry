# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "yaml"
require "open3"
require "fileutils"
require "generators/poetry/editor/editor_generator"

module Poetry
  # poetry:editor - wire the MCP server + registry-driven snippets into the
  # editors a Rails team uses. MCP writes are upserts; snippets are generated
  # from the committed registry so they can't drift from the shipped catalog.
  class EditorGeneratorTest < Rails::Generators::TestCase
    tests Poetry::EditorGenerator
    destination File.expand_path("../tmp/editor-dest", __dir__)
    setup :prepare_destination
    # The generator reads the shell for the agent that runs it; a test run
    # has to see the same nothing wherever it is run from.
    setup { Poetry::Generators::EditorChoice.environment = {} }
    teardown { Poetry::Generators::EditorChoice.environment = nil }

    def manifest
      YAML.safe_load_file(File.join(destination_root, "config/poetry_components.yml"))
    end

    def test_named_editors_are_the_only_ones_wired_and_are_remembered
      output = run_generator %w[--editor cursor]

      assert_file ".cursor/mcp.json"
      assert_file ".cursor/hooks.json"
      assert_file "bin/poetry-check-hook"
      assert_no_file ".mcp.json"
      assert_no_file ".claude/settings.json"
      assert_no_file ".vscode/mcp.json"
      assert_no_file ".vscode/poetry.code-snippets"
      assert_file ".herb.yml"
      assert_includes output, "cursor (--editor)"
      assert_equal %w[cursor], manifest["editors"]
    end

    def test_a_later_run_wires_what_was_remembered_and_nothing_else
      run_generator %w[--editor vscode]
      output = run_generator

      assert_includes output, "vscode (remembered in config/poetry_components.yml)"
      assert_file ".vscode/mcp.json"
      assert_no_file ".mcp.json"
      assert_no_file "bin/poetry-check-hook"
    end

    def test_the_agent_running_the_generator_and_an_editors_own_files_are_found
      Poetry::Generators::EditorChoice.environment = { "CLAUDECODE" => "1" }
      FileUtils.mkdir_p(File.join(destination_root, ".vscode"))
      FileUtils.mkdir_p(File.join(destination_root, ".claude/skills/poetry"))
      output = run_generator

      assert_includes output, "claude, vscode (found: claude by CLAUDECODE, vscode by .vscode)"
      assert_file ".mcp.json"
      assert_file ".claude/settings.json"
      assert_file ".vscode/mcp.json"
      assert_no_file ".cursor/mcp.json"
      assert_equal %w[claude vscode], manifest["editors"]
    end

    def test_poetrys_own_skills_folder_is_not_a_sign_of_claude_code
      FileUtils.mkdir_p(File.join(destination_root, ".claude/skills/poetry"))
      FileUtils.mkdir_p(File.join(destination_root, ".cursor"))
      output = run_generator

      assert_includes output, "cursor (found: cursor by .cursor)"
      assert_no_file ".mcp.json"
    end

    def test_none_wires_no_editor_and_an_unknown_name_is_refused_with_the_names
      output = run_generator %w[--editor none]

      assert_includes output, "none (--editor)"
      assert_no_file ".mcp.json"
      assert_no_file ".cursor/mcp.json"
      assert_no_file ".vscode/mcp.json"
      assert_no_file "bin/poetry-check-hook"
      assert_equal [], manifest["editors"]
      assert_includes capture(:stderr) {
        run_generator %w[--editor emacs]
      }.to_s + run_generator(%w[--editor emacs]).to_s,
                      "no editor called emacs - choose from claude, cursor, vscode, all or none"
    end

    def test_the_choice_joins_a_manifest_that_already_holds_components
      FileUtils.mkdir_p(File.join(destination_root, "config"))
      File.write(File.join(destination_root, "config/poetry_components.yml"),
                 "components:\n  button:\n    version: 1\n")
      run_generator %w[--editor claude,cursor]

      assert_equal({ "components" => { "button" => { "version" => 1 } }, "editors" => %w[claude cursor] }, manifest)
    end

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
      assert_equal({ "enabled" => true }, config["linter"], "every rule is on: the pin alone decides the set")

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

    # --- the check hook ---

    def test_writes_the_check_hook_and_registers_it_for_claude_code_and_cursor
      run_generator
      script = File.join(destination_root, "bin/poetry-check-hook")

      assert File.executable?(script), "bin/poetry-check-hook is executable"
      assert_match(%r{\A#!/usr/bin/env ruby}, File.read(script))
      entry = read_json(".claude/settings.json").dig("hooks", "PostToolUse", 0)

      assert_equal "Edit|Write|MultiEdit", entry["matcher"]
      assert_equal "bin/poetry-check-hook", entry.dig("hooks", 0, "command")
      cursor = read_json(".cursor/hooks.json")

      assert_equal 1, cursor["version"]
      assert_equal "bin/poetry-check-hook", cursor.dig("hooks", "postToolUse", 0, "command")
      assert_equal "Write", cursor.dig("hooks", "postToolUse", 0, "matcher")
    end

    def test_hook_upsert_keeps_existing_hooks_and_settings_and_is_idempotent
      FileUtils.mkdir_p(File.join(destination_root, ".claude"))
      existing = { "permissions" => { "allow" => ["Bash(bin/rails test:*)"] },
                   "hooks" => { "PostToolUse" => [{ "matcher" => "Bash",
                                                    "hooks" => [{ "type" => "command", "command" => "echo done" }] }],
                                "Stop" => [{ "hooks" => [{ "type" => "command", "command" => "say ok" }] }] } }
      File.write(File.join(destination_root, ".claude/settings.json"), JSON.pretty_generate(existing))
      run_generator
      merged = read_json(".claude/settings.json")

      assert_equal ["Bash(bin/rails test:*)"], merged.dig("permissions", "allow")
      assert_equal(["Bash", "Edit|Write|MultiEdit"], merged.dig("hooks", "PostToolUse").map { |hook| hook["matcher"] })
      assert_equal "say ok", merged.dig("hooks", "Stop", 0, "hooks", 0, "command")
      assert_match(%r{identical\s+\.claude/settings\.json}, run_generator)
      assert_equal 2, read_json(".claude/settings.json").dig("hooks", "PostToolUse").size
    end

    def test_hook_upsert_never_clobbers_a_jsonc_settings_file
      FileUtils.mkdir_p(File.join(destination_root, ".claude"))
      jsonc = "{\n  // my hooks\n  \"hooks\": {}\n}\n"
      File.write(File.join(destination_root, ".claude/settings.json"), jsonc)
      output = run_generator

      assert_match(%r{skip\s+\.claude/settings\.json}, output)
      assert_equal jsonc, File.read(File.join(destination_root, ".claude/settings.json"))
    end

    # --- the hook script, driven the way the editors drive it ---

    HOOK_ERB = "app/views/probe/_probe.html.erb"

    def claude_payload(relative)
      { "session_id" => "s", "hook_event_name" => "PostToolUse", "tool_name" => "Edit", "cwd" => destination_root,
        "tool_input" => { "file_path" => File.join(destination_root, relative) } }
    end

    def cursor_payload(relative)
      { "conversation_id" => "c", "hook_event_name" => "postToolUse", "tool_name" => "Write",
        "workspace_roots" => [destination_root],
        "tool_input" => { "file_path" => File.join(destination_root, relative) } }
    end

    # Runs the generated hook against a stub bin/rails that prints canned
    # check JSON, records that it ran, and exits as asked.
    def hook_run(payload, rails_json:, rails_exit: 0)
      run_generator
      FileUtils.mkdir_p(File.join(destination_root, File.dirname(HOOK_ERB)))
      File.write(File.join(destination_root, HOOK_ERB), "<div></div>\n")
      File.write(File.join(destination_root, "rails-stdout.json"), rails_json)
      FileUtils.rm_f(File.join(destination_root, "rails-was-called"))
      stub = File.join(destination_root, "bin/rails")
      File.write(stub, "#!/bin/sh\necho \"$1\" > rails-was-called\ncat rails-stdout.json\nexit #{rails_exit}\n")
      File.chmod(0o755, stub)
      Open3.capture3({ "CLAUDE_PROJECT_DIR" => destination_root }, File.join(destination_root, "bin/poetry-check-hook"),
                     stdin_data: JSON.generate(payload), chdir: destination_root)
    end

    def test_hook_feeds_errors_back_to_claude_code_as_a_blocking_report
      findings = [{ "rule" => "unknown-variant", "severity" => "error", "line" => 3, "suggestion" => "default",
                    "message" => "poetry_button has no variant primary" }]
      stdout, stderr, status = hook_run(claude_payload(HOOK_ERB), rails_json: JSON.generate(findings), rails_exit: 1)

      assert_equal 2, status.exitstatus
      assert_includes stderr, "1 error(s), 0 warning(s) in #{HOOK_ERB}"
      assert_includes stderr, "line 3: poetry_button has no variant primary (did you mean default?)"
      assert_empty stdout
      assert_equal "poetry:check[#{HOOK_ERB}]", File.read(File.join(destination_root, "rails-was-called")).strip
    end

    def test_hook_hands_warnings_to_claude_code_as_additional_context
      findings = [{ "rule" => "raw-color", "severity" => "warning", "line" => 1,
                    "message" => "raw color class bg-red-500" }]
      stdout, _stderr, status = hook_run(claude_payload(HOOK_ERB), rails_json: JSON.generate(findings))

      assert_equal 0, status.exitstatus
      context = JSON.parse(stdout).dig("hookSpecificOutput", "additionalContext")

      assert_includes context, "1 warning(s) in #{HOOK_ERB}"
      assert_includes context, "bg-red-500"
    end

    def test_hook_speaks_cursor_and_stays_silent_when_clean
      findings = [{ "rule" => "raw-color", "severity" => "warning", "line" => 1, "message" => "raw color" }]
      stdout, _stderr, status = hook_run(cursor_payload(HOOK_ERB), rails_json: JSON.generate(findings))

      assert_equal 0, status.exitstatus
      assert_includes JSON.parse(stdout)["additional_context"], "1 warning(s)"

      stdout, _stderr, status = hook_run(claude_payload(HOOK_ERB), rails_json: "[]")

      assert_equal 0, status.exitstatus
      assert_empty stdout
    end

    def test_hook_ignores_anything_but_app_templates_without_booting_rails
      stdout, _stderr, status = hook_run(claude_payload("app/models/user.rb"), rails_json: "[]")

      assert_equal 0, status.exitstatus
      assert_empty stdout
      refute_path_exists File.join(destination_root, "rails-was-called"), "bin/rails never ran"
    end

    def test_hook_fails_open_when_the_check_cannot_run
      stdout, stderr, status = hook_run(claude_payload(HOOK_ERB), rails_json: "boom: herb missing", rails_exit: 1)

      assert_equal 1, status.exitstatus
      assert_includes stderr, "did not run"
      assert_empty stdout
    end
  end
end
