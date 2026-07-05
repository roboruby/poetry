# frozen_string_literal: true

require "json"

module Poetry
  module Core
    # poetry-agent: the MCP server projecting the component contract
    # over Model Context Protocol so an agent in Claude Code / Cursor queries
    # the LIVE registry and runs the linter as a tool. Thin - it projects the
    # surfaces already built (Registry + LlmsText + Check), never a second
    # source. Read-only, progressive-disclosure (brief|detailed|full), and
    # verdict-returning (check returns per-finding pass/fail).
    #
    # Transport is newline-delimited JSON-RPC 2.0 over stdio (own the supply
    # chain - no MCP SDK dependency). #handle is a pure request->
    # response function (testable without stdio); #serve is the thin loop.
    #
    # v1 is the read/verify surface. The heavier roadmap - verify_screen
    # running the eval gate array, component:// artifact resources, tag
    # browsing, StreamableHTTP - is maturity-gated and NOT in this cut.
    module Agent
      PROTOCOL_VERSION = "2025-06-18"
      SERVER_INFO = { "name" => "poetry-agent", "version" => Poetry::Core::VERSION }.freeze

      TOOLS = [
        {
          "name" => "list_components",
          "description" => "List every poetry component (name, helper, one-line surface). Start here; " \
                           "then describe_component for the full contract.",
          "inputSchema" => { "type" => "object", "properties" => {} },
          "annotations" => { "readOnlyHint" => true }
        },
        {
          "name" => "describe_component",
          "description" => "The contract for one component. detail: brief (summary), detailed " \
                           "(+ options/variants/slots), full (+ Stimulus wiring + agent rules).",
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "name" => { "type" => "string", "description" => "component name, e.g. button or command_dialog" },
              "detail" => { "type" => "string", "enum" => %w[brief detailed full], "default" => "detailed" }
            },
            "required" => ["name"]
          },
          "annotations" => { "readOnlyHint" => true }
        },
        {
          "name" => "check",
          "description" => "Lint ERB source against the poetry contracts WITHOUT rendering - unknown " \
                           "components/options/variants/wiring + raw colors. Returns a verdict and findings.",
          "inputSchema" => {
            "type" => "object",
            "properties" => { "source" => { "type" => "string", "description" => "the ERB template source" } },
            "required" => ["source"]
          },
          "annotations" => { "readOnlyHint" => true }
        }
      ].freeze

      # The server: constructed with the registry root (and the host's helper
      # names, so check knows the group/provider helpers). Everything read is
      # the live committed registry.
      class Server
        def self.from_registry(root, helpers: nil)
          entries = YAML.load_file(Pathname.new(root).join(Registry::RELATIVE_PATH), aliases: true)
                        .fetch("components")
          new(entries: entries, catalog: Check::Catalog.new(entries, helpers: helpers))
        end

        def initialize(entries:, catalog:)
          @entries = entries
          @catalog = catalog
        end

        # A JSON-RPC 2.0 request hash -> a response hash (or nil for a
        # notification, which gets no reply).
        def handle(request)
          id = request["id"]
          case request["method"]
          when "initialize" then result(id, initialize_result)
          when "tools/list" then result(id, { "tools" => TOOLS })
          when "tools/call" then result(id, call_tool(request["params"] || {}))
          when %r{\Anotifications/} then nil
          else error(id, -32_601, "method not found: #{request["method"]}")
          end
        rescue StandardError => e
          error(id, -32_603, e.message)
        end

        # The thin stdio loop: newline-delimited JSON-RPC in, replies out.
        # A malformed line yields a parse error, never a crashed server.
        def serve(input: $stdin, output: $stdout)
          input.each_line do |line|
            line = line.strip
            next if line.empty?

            response =
              begin
                handle(JSON.parse(line))
              rescue JSON::ParserError => e
                error(nil, -32_700, "parse error: #{e.message}")
              end
            next unless response

            output.puts(JSON.generate(response))
            output.flush
          end
        end

        private

        def initialize_result
          {
            "protocolVersion" => PROTOCOL_VERSION,
            "serverInfo" => SERVER_INFO,
            "capabilities" => { "tools" => {} }
          }
        end

        def call_tool(params)
          name = params["name"]
          arguments = params["arguments"] || {}
          text =
            case name
            when "list_components" then list_components
            when "describe_component" then describe_component(arguments)
            when "check" then check(arguments)
            else return tool_content("unknown tool: #{name}", error: true)
            end
          tool_content(text)
        end

        # --- the tools (project the built surfaces) ---

        def list_components
          @entries.map do |path, entry|
            interactive = entry["controllers"]&.any? ? " [interactive]" : ""
            "- #{title(path)} (`#{helper(path)}`)#{interactive}: #{summary(entry)}"
          end.join("\n")
        end

        def describe_component(arguments)
          path = resolve(arguments["name"])
          return "no such component: #{arguments["name"].inspect} - call list_components" unless path

          entry = @entries.fetch(path)
          detail = arguments.fetch("detail", "detailed")
          lines = ["# #{title(path)} (`#{helper(path)}`)", summary(entry)]
          lines.concat(surface_lines(entry)) if %w[detailed full].include?(detail)
          lines.concat(full_lines(entry)) if detail == "full"
          lines.join("\n")
        end

        def check(arguments)
          findings = Check.lint(arguments["source"].to_s, catalog: @catalog)
          errors = findings.count { |finding| finding.severity == :error }
          verdict = errors.zero? ? "PASS" : "FAIL"
          report = findings.map { |finding| "- [#{finding.severity}] line #{finding.line}: #{finding.message}" }
          (["#{verdict} - #{errors} error(s), #{findings.length - errors} warning(s)"] + report).join("\n")
        end

        # --- shared projections ---

        def surface_lines(entry)
          lines = []
          (entry["styles"] + entry["options"]).each do |prop|
            suffix = prop["variants"] ? " (#{prop["variants"].join("|")})" : ""
            lines << "- #{prop["name"]}: #{prop["type"]}#{suffix}"
          end
          slots = (entry["slots"] || []).map { |slot| slot["name"] }
          lines << "- slots: #{slots.join(", ")}" if slots.any?
          lines
        end

        def full_lines(entry)
          lines = (entry["controllers"] || []).map do |controller|
            "- wiring #{controller["identifier"]}: actions #{(controller["actions"] || []).join(", ")}"
          end
          (entry["agent_rules"] || []).each { |rule| lines << "- RULE: #{rule}" }
          lines
        end

        def summary(entry)
          styles = entry["styles"].map { |style| style["variants"] ? style["variants"].join("|") : style["name"] }
          styles.empty? ? "no style attributes" : styles.join("; ")
        end

        # name may be the title (button, command_dialog) or the full path.
        def resolve(name)
          return name if @entries.key?(name)

          @entries.keys.find { |path| title(path) == name }
        end

        def title(path) = path.split("/").drop(2).join("_")
        def helper(path) = "poetry_#{title(path)}"

        def result(id, value) = { "jsonrpc" => "2.0", "id" => id, "result" => value }

        def error(id, code,
                  message)
          { "jsonrpc" => "2.0", "id" => id, "error" => { "code" => code, "message" => message } }
        end

        def tool_content(text,
                         error: false)
          { "content" => [{ "type" => "text", "text" => text }], "isError" => error }
        end
      end
    end
  end
end
