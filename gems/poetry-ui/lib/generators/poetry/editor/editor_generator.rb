# frozen_string_literal: true

require "rails/generators"
require "json"
require "yaml"
require "time"

module Poetry
  # `rails g poetry:editor` - wire the poetry agent surface into the editors a
  # Rails team actually uses. poetry has no bespoke extension (a possible
  # future direction); what it DOES have is a standard MCP stdio server and a
  # source-generated component registry, so this generator emits:
  #
  #   .mcp.json            Claude Code   (mcpServers)
  #   .cursor/mcp.json     Cursor        (mcpServers)
  #   .vscode/mcp.json     VS Code       (servers + type: stdio)
  #   .vscode/poetry.code-snippets   one snippet per poetry_* helper, with the
  #                                   real variant/size enums as tab-stop choices
  #   .herb.yml            Herb (linter / formatter / language server), unless
  #                        the app already has one
  #   .stimulus-lsp/config.json   poetry's controller identifiers for Stimulus LSP
  #                               (upsert: an existing ignore list keeps its entries)
  #
  # The MCP writes are upserts: an existing config keeps its other servers and
  # gains a `poetry` entry; a config that already has one is left untouched; a
  # JSONC file poetry can't parse is reported, never clobbered. Editors whose
  # MCP config is global / IDE-managed (Zed, Windsurf, RubyMine) get a
  # copy-paste block printed instead.
  #
  # @example
  #   bin/rails g poetry:editor
  class EditorGenerator < Rails::Generators::Base
    # Editors whose MCP config is global or IDE-managed, so poetry prints a
    # paste-block instead of writing a project file.
    MANUAL_EDITORS = <<~TEXT
      Zed        settings.json ->
                 "context_servers": { "poetry": { "command": { "path": "bundle", "args": ["exec", "poetry-agent"] } } }
      Windsurf   ~/.codeium/windsurf/mcp_config.json ->
                 { "mcpServers": { "poetry": { "command": "bundle", "args": ["exec", "poetry-agent"] } } }
      RubyMine   Settings -> Tools -> AI Assistant -> Model Context Protocol (MCP) ->
                 add a stdio server: command `bundle exec poetry-agent` (or import .mcp.json). RubyMine 2025.2+.
    TEXT

    # The Herb toolchain (HTML+ERB parser, linter, formatter, language server)
    # reads one file. Poetry templates are gated to parse AND compile under
    # Herb (Rails core's ERB engine since 8.2), so a Poetry app can run the
    # whole toolchain; two linter rules misread ViewComponent slot setters on
    # helper-yielded builders today, so they start off with the upstream
    # issues to watch. The version pin keeps a linter upgrade from enabling
    # rules silently.
    HERB_CONFIG = <<~YML
      # Herb toolchain configuration (linter / formatter / language server).
      # https://herb-tools.dev/configuration - written by `rails g poetry:editor`.
      version: 0.10.3

      framework: actionview

      linter:
        enabled: true
        rules:
          # `<%= poetry_card do |card| %><% card.with_title(...) %>` is flagged as
          # a discarded value until marcoroth/herb#2426 lands.
          erb-no-unused-expressions:
            enabled: false
          # `<% item.with_icon { ... } %>` (brace-form slot setters) is flagged and
          # the autofix renders the wrong thing - marcoroth/herb#2340.
          actionview-no-silent-helper:
            enabled: false

      formatter:
        enabled: false
    YML

    # Where the Herb language server comes from, per editor.
    HERB_EDITORS = <<~TEXT
      VS Code    install the "Herb LSP" extension (marcoroth.herb-lsp); Stimulus LSP (marcoroth.stimulus-lsp)
                 understands the same HTML+ERB
      Zed        ships inside the official Ruby extension - nothing to add
      Neovim     npm install -g @herb-tools/language-server, then lspconfig's herb_ls
      CI         npx --yes @herb-tools/linter app   (or bundle exec herb lint)
      Stimulus   .stimulus-lsp/config.json lists poetry's controllers for Stimulus LSP - it checks YOUR
                 controllers; bin/rails poetry:check validates poetry's (data: keywords included)
    TEXT

    # Stimulus LSP resolves identifiers from the app's controller directories
    # and node_modules; controllers a gem serves through importmap are
    # invisible to it, so every hand-written `poetry--...` descriptor reads
    # as an invalid controller with a quick-fix that scaffolds a bogus file.
    # The LSP's one lever is an ignore list of exact identifiers, so poetry
    # lists every controller its installed gems ship. Those descriptors are
    # poetry:check's to validate (kwargs included); the LSP keeps yours.
    STIMULUS_LSP_VERSION = "1.1.2" # the schema's writer version; the LSP rewrites it on its own saves

    desc "Wire poetry's MCP server + component snippets + Herb and Stimulus LSP config into your editors " \
         "(.mcp.json / .cursor/mcp.json / .vscode/mcp.json + .vscode/poetry.code-snippets + .herb.yml + " \
         ".stimulus-lsp/config.json)"

    # Step: upserts the poetry server into .mcp.json.
    # @api private
    def write_claude_code_config
      upsert_mcp ".mcp.json", "mcpServers", stdio: false
    end

    # Step: upserts the poetry server into .cursor/mcp.json.
    # @api private
    def write_cursor_config
      upsert_mcp ".cursor/mcp.json", "mcpServers", stdio: false
    end

    # Step: upserts the poetry server into .vscode/mcp.json.
    # @api private
    def write_vscode_config
      upsert_mcp ".vscode/mcp.json", "servers", stdio: true
    end

    # Step: writes one VS Code snippet per poetry_* helper.
    # @api private
    def write_snippets
      create_file ".vscode/poetry.code-snippets", "#{JSON.pretty_generate(snippets)}\n", force: true
    end

    # Step: writes .herb.yml for the Herb toolchain, unless the app has one.
    # @api private
    def write_herb_config
      if File.exist?(File.join(destination_root, ".herb.yml"))
        say_status :skip, ".herb.yml exists - keeping yours (poetry's rule notes: /editors on the docs site)",
                   :yellow
      else
        create_file ".herb.yml", HERB_CONFIG
      end
    end

    # Step: lists poetry's controller identifiers for Stimulus LSP (upsert).
    # @api private
    def write_stimulus_lsp_config
      upsert_stimulus_lsp ".stimulus-lsp/config.json"
    end

    # Step: prints the paste-blocks for IDE-managed MCP configs.
    # @api private
    def announce_manual_editors
      say "\npoetry:editor - editors with global / IDE-managed MCP config (paste-blocks):", :green
      say MANUAL_EDITORS
      say "\npoetry:editor - Herb (HTML+ERB linter + language server), configured by .herb.yml:", :green
      say HERB_EDITORS
      say "Full setup + a per-editor matrix: /editors on the docs site.\n"
    end

    private

    # The stdio server every host launches the same way. Zero config beyond the
    # bundle exec line; the agent auto-locates the gem and reads the committed
    # registry (boot-free).
    def server_entry(stdio:)
      entry = { "command" => "bundle", "args" => %w[exec poetry-agent] }
      stdio ? { "type" => "stdio" }.merge(entry) : entry
    end

    def upsert_mcp(relative, key, stdio:)
      path = File.join(destination_root, relative)
      unless File.exist?(path)
        create_file relative, "#{JSON.pretty_generate(key => { "poetry" => server_entry(stdio: stdio) })}\n"
        return
      end

      data = parse_json(File.read(path))
      return say_status(:skip, "#{relative} isn't plain JSON (JSONC?) - add the poetry server by hand", :yellow) \
        if data.nil?

      servers = (data[key] ||= {})
      return say_status(:identical, relative, :blue) if servers["poetry"]

      servers["poetry"] = server_entry(stdio: stdio)
      File.write(path, "#{JSON.pretty_generate(data)}\n")
      say_status :update, "#{relative} (added the poetry server)", :green
    end

    # Every poetry-owned identifier the installed gems ship (core + any
    # registered manifest), sorted for a stable file.
    def poetry_identifiers
      Poetry::Core::Stimulus::Manifest.catalog.keys.sort
    end

    def upsert_stimulus_lsp(relative)
      path = File.join(destination_root, relative)
      identifiers = poetry_identifiers
      unless File.exist?(path)
        create_file relative, "#{JSON.pretty_generate(stimulus_lsp_config(identifiers))}\n"
        return
      end

      data = parse_json(File.read(path))
      return say_status(:skip, "#{relative} isn't plain JSON - add poetry's identifiers by hand", :yellow) if data.nil?

      options = (data["options"] ||= {})
      ignored = Array(options["ignoredControllerIdentifiers"])
      missing = identifiers - ignored
      return say_status(:identical, relative, :blue) if missing.empty?

      options["ignoredControllerIdentifiers"] = (ignored + missing).uniq.sort
      options["ignoredAttributes"] = Array(options["ignoredAttributes"])
      data["updatedAt"] = Time.now.utc.iso8601
      File.write(path, "#{JSON.pretty_generate(data)}\n")
      say_status :update, "#{relative} (+#{missing.size} poetry controller identifiers)", :green
    end

    def stimulus_lsp_config(identifiers)
      now = Time.now.utc.iso8601
      { "version" => STIMULUS_LSP_VERSION, "createdAt" => now, "updatedAt" => now,
        "options" => { "ignoredControllerIdentifiers" => identifiers, "ignoredAttributes" => [] } }
    end

    # nil for anything we can't safely round-trip. JSONC comments are detected
    # BEFORE parsing: some json versions silently accept `//`/`/* */` and would
    # then drop the comments on re-serialize - poetry never clobbers a config it
    # can't preserve.
    def parse_json(text)
      return nil if text.match?(%r{^\s*//}) || text.include?("/*")

      JSON.parse(text)
    rescue JSON::ParserError
      nil
    end

    # One snippet per main component helper (poetry_<name>), driven by the
    # committed registry so it never drifts from the shipped catalog. A block
    # form for components that compose via slots; inline for atoms. The primary
    # enum (variant, else the first declared one) becomes a choice tab-stop, so
    # the completion only offers values that actually exist.
    def snippets
      registry = YAML.safe_load_file(Poetry::Ui.root.join("config/component_registry.yml"))
      registry.fetch("components").keys.sort.to_h do |path|
        name = path.delete_prefix("poetry/ui/").tr("/", "_")
        component = registry.fetch("components").fetch(path)
        [
          "poetry #{name.tr("_", " ")}",
          { "prefix" => "poetry_#{name}", "scope" => "erb",
            "body" => snippet_body(name, component), "description" => "poetry #{humanize(name)} component" }
        ]
      end
    end

    def snippet_body(name, component)
      call = "poetry_#{name}#{enum_argument(component)}"
      if Array(component["slots"]).any?
        ["<%= #{call} do |c| %>", "\t$0", "<% end %>"]
      else
        "<%= #{call} %>$0"
      end
    end

    # `(variant: :${1|a,b,c|})` for the primary enum, or "" when the component
    # declares none. Enums come from BOTH the styles DSL (variant/size) and
    # options (tag/orientation/...); a declared `variant` wins.
    def enum_argument(component)
      enums = (Array(component["styles"]) + Array(component["options"])).select { |o| o["variants"] }
      chosen = enums.find { |o| o["name"] == "variant" } || enums.first
      return "" unless chosen

      "(#{chosen["name"]}: :${1|#{Array(chosen["variants"]).join(",")}|})"
    end

    def humanize(name)
      name.split("_").map(&:capitalize).join(" ")
    end
  end
end
