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
          "name" => "compose",
          "description" => "CALL THIS FIRST for every brief, before writing any ERB. Give it the task " \
                           "text; it routes to the right starting point: a matching vetted block " \
                           "(returns the full source to adapt in place - the known winning path for " \
                           "pages) or the matching components for single-component work. Composing a " \
                           "page from scratch when a block matched is the known losing path.",
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "brief" => { "type" => "string",
                           "description" => "the task text, verbatim (a sentence is enough)" }
            },
            "required" => ["brief"]
          },
          "annotations" => { "readOnlyHint" => true }
        },
        {
          "name" => "list_components",
          "description" => "List every poetry component (name, helper, one-line surface). Start here " \
                           "AFTER compose has routed the brief; then describe_component for the full " \
                           "contract.",
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
                           "components/options/variants/wiring, raw colors, icon names, enum values, " \
                           "typed-slot props, helper/setter arity, yield-less blocks, setter keywords, " \
                           "required content blocks, and required slots a call never set. Returns a " \
                           "verdict and findings. Run this as the LAST action after the final edit - " \
                           "an edit after your last check is unverified.",
          "inputSchema" => {
            "type" => "object",
            "properties" => { "source" => { "type" => "string", "description" => "the ERB template source" } },
            "required" => ["source"]
          },
          "annotations" => { "readOnlyHint" => true }
        },
        {
          "name" => "list_blocks",
          "description" => "List the vetted composed-screen blocks (name, title, composed components). " \
                           "compose(brief) routes to the right one automatically; browse here when " \
                           "you want the full catalog, then describe_block for source.",
          "inputSchema" => { "type" => "object", "properties" => {} },
          "annotations" => { "readOnlyHint" => true }
        },
        {
          "name" => "describe_block",
          "description" => "One block's contract AND its full ERB source, ready to adapt - the " \
                           "boot-free equivalent of `bin/rails g poetry:block <name>`.",
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "name" => { "type" => "string", "description" => "block name, e.g. data-index or app-shell" }
            },
            "required" => ["name"]
          },
          "annotations" => { "readOnlyHint" => true }
        }
      ].freeze

      # The server: constructed with the registry root (and the host's helper
      # names, so check knows the group/provider helpers - though the
      # registry's own "helpers" section now carries those boot-free).
      # icon_names: the active icon set's names, so the check tool validates
      # icon values by membership, not just shape. Everything read is the
      # live committed registry.
      class Server
        def self.from_registry(root, helpers: nil, icon_names: nil)
          payload = YAML.load_file(Pathname.new(root).join(Registry::RELATIVE_PATH), aliases: true)
          entries = payload.fetch("components")
          catalog = Check::Catalog.new(entries, helpers: helpers,
                                                helper_entries: payload["helpers"], icon_names: icon_names,
                                                helper_args: payload["helper_args"])
          new(entries: entries, catalog: catalog, blocks: payload["blocks"] || {}, root: root)
        end

        def initialize(entries:, catalog:, blocks: {}, root: nil)
          @entries = entries
          @catalog = catalog
          @blocks = blocks
          @root = root
        end

        # compose routing: the strong-match threshold, and the words
        # too generic to signal a block - connectives, task verbs, and
        # component-anatomy words (title/description/action) every brief
        # uses regardless of scale.
        STRONG_MATCH = 4
        STOPWORDS = %w[
          the a an and or with for of to in on at from into by over under this that it its as is are
          be has have should must can will each per when where build create make add show include
          using use page screen view ui app real realistic data
          title titles description descriptions action actions
        ].to_set.freeze

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
            when "compose" then compose(arguments)
            when "list_components" then list_components
            when "describe_component" then describe_component(arguments)
            when "check" then check(arguments)
            when "list_blocks" then list_blocks
            when "describe_block" then describe_block(arguments)
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
          # The block back-reference: a screen containing this
          # component should start from the vetted composition.
          blocks = @blocks.select { |_name, block| block["components"].include?(title(path)) }.keys
          if blocks.any?
            lines << "- in blocks: #{blocks.join(", ")} - for a screen, start there (describe_block), " \
                     "not from scratch"
          end
          lines.join("\n")
        end

        def check(arguments)
          findings = Check.lint(arguments["source"].to_s, catalog: @catalog)
          errors = findings.count { |finding| finding.severity == :error }
          verdict = errors.zero? ? "PASS" : "FAIL"
          report = findings.map do |finding|
            hint = finding.suggestion ? " (did you mean #{finding.suggestion}?)" : ""
            "- [#{finding.severity}] line #{finding.line}: #{finding.message}#{hint}"
          end
          (["#{verdict} - #{errors} error(s), #{findings.length - errors} warning(s)"] + report).join("\n")
        end

        # The compose router: the unconditional first move.
        # proved advisory prose does not move behavior - the design skill
        # fired in 24/31 arms and composition did not move, while the
        # blocks surface (the one measured composition win, 21-9) sat
        # untouched in 28/31. compose makes blocks the DEFAULT path: one
        # call routes any brief either into a vetted block (source inline,
        # nothing left to decide) or to the matching components. Scoring
        # is deterministic lexical overlap - curated block keywords count
        # double, title/description tokens count once, all over distinct
        # stems (calibrated against the benchmark brief set: page-scale
        # briefs route to their block, single-component briefs stay on the
        # component path).
        def compose(arguments)
          brief = arguments["brief"].to_s.strip
          return "compose needs the brief text - pass the task description verbatim.\n#{list_blocks}" if brief.empty?

          tokens = brief_tokens(brief)
          scored = @blocks.map { |name, entry| [name, entry, block_score(entry, tokens)] }
                          .sort_by { |name, _entry, score| [-score, name] }
          components = matched_components(tokens)
          best = scored.first
          if best && best[2] >= STRONG_MATCH
            block_route(scored, components)
          else
            component_route(scored, components)
          end
        end

        # Distinct stems (crude: trailing-s stripped), so "settings" and
        # "setting" are ONE hit, not a double-counted pair.
        def brief_tokens(brief)
          stems = brief.downcase.scan(/[a-z0-9][a-z0-9_-]+/).map { |token| token.delete_suffix("s") }
          stems.uniq.reject { |stem| stem.length < 3 || STOPWORDS.include?(stem) }.to_set
        end

        # Curated keywords count double; title/description tokens count
        # once. Component names stay OUT of the corpus - a lone-button
        # brief must not route to a block that happens to compose buttons.
        # Distinct stem hits only - repetition is not signal.
        def block_score(entry, tokens)
          keywords = (entry["keywords"] || []).to_set { |word| word.delete_suffix("s") }
          corpus = "#{entry["title"]} #{entry["description"]}"
          corpus_tokens = corpus.downcase.scan(/[a-z0-9][a-z0-9_-]+/)
                                .to_set { |token| token.delete_suffix("s") }
          tokens.sum do |token|
            if keywords.include?(token) then 2
            elsif corpus_tokens.include?(token) then 1
            else 0
            end
          end
        end

        # Component titles fully present in the brief (every underscore part
        # matched: date_picker needs both "date" and "picker").
        def matched_components(tokens)
          @entries.keys.map { |path| title(path) }.select do |name|
            name.split("_").all? { |part| tokens.include?(part.delete_suffix("s")) }
          end.sort.first(8)
        end

        def block_route(scored, components)
          name, entry, score = scored.first
          runners = scored.drop(1).select { |_n, _e, s| s.positive? }.first(2)
          lines = ["STRONG BLOCK MATCH (score #{score}): start from `#{name}` and adapt it in place.", "",
                   "# #{entry["title"]} (`#{name}`)", entry["description"],
                   "Composes: #{entry["components"].join(", ")}.",
                   "In an app: `bin/rails g poetry:block #{name}` copies it into app/views/blocks/.",
                   "", "Source (adapt in place - replace the sample content, keep the structure):", "",
                   block_source(entry)]
          if runners.any?
            described = runners.map { |n, e, s| "`#{n}` (#{e["title"]}, score #{s})" }.join(", ")
            lines << ""
            lines << "Runners-up: #{described} - describe_block returns their source."
          end
          matched = components.any? ? " - matched here: #{components.join(", ")}" : ""
          lines << "Fill the gaps with components (describe_component)#{matched}."
          lines << "Finish with the check tool as the LAST action after your final edit."
          lines.join("\n")
        end

        def component_route(scored, components)
          lines = ["No block covers this brief - component-scale work."]
          lines << if components.any?
                     "Matched components: #{components.map { |name| "#{name} (`poetry_#{name}`)" }.join(", ")} - " \
                       "describe_component for the contracts."
                   else
                     "No component name matched either - list_components for the catalog."
                   end
          if scored.any?
            lines << ""
            lines << "If this grows into a SCREEN, start from a block (describe_block for source):"
            scored.each { |name, entry, _score| lines << "- #{name}: #{entry["title"]} - #{entry["description"]}" }
          end
          lines << "Finish with the check tool as the LAST action after your final edit."
          lines.join("\n")
        end

        def block_source(entry)
          Pathname.new(@root).join(entry.fetch("template")).read
                  .sub(/\A<%#\s*poetry:block[^%]*%>\n?/, "").rstrip
        rescue StandardError => e
          "block source unavailable: #{e.message} - use `bin/rails g poetry:block` instead"
        end

        def list_blocks
          return "no blocks in this registry" if @blocks.empty?

          @blocks.map do |name, entry|
            "- #{name}: #{entry["title"]} - #{entry["description"]} " \
              "[composes: #{entry["components"].join(", ")}]"
          end.join("\n")
        end

        def describe_block(arguments)
          name = arguments["name"].to_s.tr("_", "-")
          entry = @blocks[name]
          return "no such block: #{arguments["name"].inspect} - call list_blocks" unless entry

          source = Pathname.new(@root).join(entry.fetch("template")).read
                           .sub(/\A<%#\s*poetry:block[^%]*%>\n?/, "").rstrip
          ["# #{entry["title"]} (`#{name}`)", entry["description"],
           "Composes: #{entry["components"].join(", ")}.",
           "In an app: `bin/rails g poetry:block #{name}` copies this into app/views/blocks/.",
           "", "Source (adapt freely - the sample content is meant to be replaced):", "", source].join("\n")
        rescue StandardError => e
          "block source unavailable: #{e.message}"
        end

        # --- shared projections ---

        def surface_lines(entry)
          lines = []
          lines << "- content block REQUIRED (#{entry["requires_content"]})" if entry["requires_content"]
          (entry["required_slots"] || {}).each do |setter, hint|
            lines << "- slot REQUIRED: with_#{setter} (#{hint}) - a call without it raises"
          end
          (entry["styles"] + entry["options"]).each do |prop|
            facets = []
            facets << prop["variants"].join("|") if prop["variants"]
            facets << "required" if prop["required"] && !prop.key?("default")
            facets << "format: #{prop["format"]}" if prop["format"]
            suffix = facets.any? ? " (#{facets.join("; ")})" : ""
            lines << "- #{prop["name"]}: #{prop["type"]}#{suffix}"
          end
          slots = (entry["slots"] || []).map do |slot|
            facets = []
            if slot["types"]
              args = slot["setter_args"]
              convention = args && slot["types"].all? { |type| args[type]&.zero? } ? " - options as keywords" : ""
              facets << "types #{slot["types"].join("|")}#{convention}"
            end
            facets << "takes #{helper(slot["component"])} props, not a block" if slot["component"]
            # The crash seams, stated where agents read them.
            if (yieldless = slot["yieldless"])
              setters = yieldless.map { |name| "with_#{name}" }.join("/")
              facets << "#{setters} #{yieldless.size == 1 ? "yields" : "yield"} NOTHING to the block - no |param|"
            end
            (slot["setter_kwargs"] || {}).each do |setter, keywords|
              facets << "with_#{setter} keywords: #{keywords.map { |keyword| "#{keyword}:" }.join(", ")} ONLY"
            end
            (slot["required_content"] || {}).each do |setter, hint|
              facets << "with_#{setter} REQUIRES a content block (#{hint})"
            end
            (slot["builders"] || {}).each do |setter, surface|
              (surface["required_slots"] || {}).each do |required, hint|
                facets << "each with_#{setter} REQUIRES with_#{required} inside its block (#{hint})"
              end
            end
            "#{slot["name"]}#{" (#{facets.join("; ")})" if facets.any?}"
          end
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
