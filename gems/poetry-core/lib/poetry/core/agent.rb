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
          "name" => "build_page",
          "description" => "The GUIDED build for a whole SCREEN/page/dashboard - use this over " \
                           "compose when the job is a full page. Give the intent verbatim; it runs a " \
                           "five-step workflow and each call returns ONE step plus the exact next call: " \
                           "probe (host setup) -> plan (page architecture: section order, states, edge " \
                           "cases) -> direct (theme-derived creative direction) -> snippets (the block/" \
                           "components to start from) -> verify (the executable check gate). The workflow " \
                           "is DONE only on a PASS from check - a real verdict, not a claim. Omit step to " \
                           "start; the entry routes by your verb (review/harden stay read-only). " \
                           "Out-of-order steps are answered, never refused.",
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "intent" => { "type" => "string",
                            "description" => "the page you are building, verbatim (a sentence is enough)" },
              "step" => { "type" => "string", "enum" => %w[probe plan direct snippets verify],
                          "description" => "the workflow step to run; omit to start at the routed entry" },
              "source" => { "type" => "string",
                            "description" => "verify step only: the ERB you built, to run through check" }
            },
            "required" => ["intent"]
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
                           "required content blocks, required slots a call never set, and any-of " \
                           "contracts (Button's visible content, Command's accessible name). Returns a " \
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
        },
        {
          "name" => "list_recipes",
          "description" => "List the installable recipes - multi-file payloads beyond components " \
                           "(skill bundles, scaffold template sets, screen slices) served by the " \
                           "poetry registry. Install one with `bin/rails g poetry:add <name>` or " \
                           "any shadcn-compatible client.",
          "inputSchema" => { "type" => "object", "properties" => {} },
          "annotations" => { "readOnlyHint" => true }
        },
        {
          "name" => "get_skill",
          "description" => "A poetry Claude Code skill served at runtime - for hosts where " \
                           "the installed .claude/skills files are absent (hosted agents, sessions " \
                           "that never ran the generator). name: poetry (component usage, generated " \
                           "from this registry), poetry-design (page-composition taste), or " \
                           "poetry-component (authoring app-owned components). Returns " \
                           "SKILL.md plus the file index; pass file: to fetch one reference " \
                           "(e.g. references/forms.md). The installed skills are the same text - " \
                           "when .claude/skills/poetry exists, read it there instead.",
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "name" => { "type" => "string", "enum" => %w[poetry poetry-design poetry-component],
                          "default" => "poetry" },
              "file" => { "type" => "string",
                          "description" => "one skill file, e.g. references/deciding.md " \
                                           "(omit for SKILL.md + the file index)" }
            }
          },
          "annotations" => { "readOnlyHint" => true }
        },
        {
          "name" => "guidance",
          "description" => "Curated composition guidance, per topic: 'deciding' = the " \
                           "which-component decision tree (interaction model first). The same " \
                           "text the installed usage skill carries - reach it here when the " \
                           "skill is not installed.",
          "inputSchema" => {
            "type" => "object",
            "properties" => {
              "topic" => { "type" => "string", "description" => "guidance topic; currently: deciding" }
            },
            "required" => ["topic"]
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
      #
      # @example Serve the committed registry over stdio
      #   Poetry::Core::Agent::Server.from_registry("registry").serve
      class Server
        # skills: skill name => a zero-arg callable returning the skill's
        # {relative path => content} file map (the get_skill tool).
        # Lazy because the usage skill is generated from the registry on
        # first fetch - server boot stays instant.
        def self.from_registry(root, helpers: nil, icon_names: nil, skills: {}, app_root: nil, recipes: [])
          committed = Registry.committed(root)
          catalog = Check::Catalog.new(committed.entries, helpers: helpers,
                                                          helper_entries: committed.helpers,
                                                          icon_names: icon_names,
                                                          helper_args: committed.helper_args)
          new(entries: committed.entries, catalog: catalog, blocks: committed.blocks || {},
              root: root, skills: skills, app_root: app_root, recipes: recipes)
        end

        # app_root: the HOST app directory (where `bundle exec poetry-agent`
        # runs, i.e. Dir.pwd), so build_page's probe/direct steps can read
        # the app's config/theme. nil => the host is not inspected and those
        # steps degrade gracefully; the registry read (root) is unaffected.
        # recipes: registry-item SUMMARIES (content-free) from the owning
        # gem's RecipeItems projection - the exe passes them so this class
        # stays poetry-ui-free.
        # rubocop:disable Metrics/ParameterLists
        def initialize(entries:, catalog:, blocks: {}, root: nil, skills: {}, app_root: nil, recipes: [])
          @entries = entries
          @catalog = catalog
          @blocks = blocks
          @root = root
          @skills = skills
          @skill_files = {}
          @app_root = app_root
          @recipes = recipes
        end
        # rubocop:enable Metrics/ParameterLists

        # compose routing: the strong-match threshold, and the words
        # too generic to signal a block - connectives, task verbs, and
        # component-anatomy words (title/description/action) every brief
        # uses regardless of scale.
        STRONG_MATCH = 4
        # build_page: the guided workflow's five steps, the themes
        # its probe/direct steps sniff for, and the plan step's match floor
        # (one curated archetype keyword = 2, so 2 is the weakest real hit).
        STEPS = %w[probe plan direct snippets verify].freeze
        THEMES = %w[default vega nova mira rhea maia luma lyra sera].freeze
        ARCHETYPE_MATCH = 2
        STOPWORDS = %w[
          the a an and or with for of to in on at from into by over under this that it its as is are
          be has have should must can will each per when where build create make add show include
          using use page screen view ui app real realistic data
          title titles description descriptions action actions
        ].to_set.freeze

        # A JSON-RPC 2.0 request hash -> a response hash (or nil for a
        # notification, which gets no reply).
        #
        # @param request [Hash] one parsed JSON-RPC 2.0 request
        # @return [Hash, nil] the response hash, or nil for a notification
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
            when "build_page" then build_page(arguments)
            when "list_components" then list_components
            when "describe_component" then describe_component(arguments)
            when "check" then check(arguments)
            when "list_blocks" then list_blocks
            when "describe_block" then describe_block(arguments)
            when "list_recipes" then list_recipes
            when "get_skill" then get_skill(arguments)
            when "guidance" then guidance(arguments)
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

        # The compose router: the unconditional first move. Measured runs
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

        # --- build_page: the guided page workflow ---
        #
        # A stateless state machine: the STEP is carried in the arguments,
        # so #handle stays a pure function and the server stays boot-free -
        # no session storage. Each step response ends with the exact next
        # call. With no step, the entry routes on the intent's VERB:
        # review/harden stay read-only so an audit never becomes an edit;
        # shape plans without probing; implement runs the full sequence.
        def build_page(arguments)
          intent = arguments["intent"].to_s.strip
          return "build_page needs the intent - the page you are building, in a sentence." if intent.empty?

          step = arguments["step"].to_s.strip
          return route_entry(intent) if step.empty?

          run_step(step, intent, arguments)
        end

        # The request-mode router: resolve the mode from the verb BEFORE
        # acting. Only a clear review/harden/shape
        # verb diverts; a page description with no verb is an implement.
        def request_mode(intent)
          text = intent.downcase
          return :review if text.match?(/\b(review|audit|assess|evaluate|inspect|critique)\b/)
          return :harden if text.match?(/\b(harden|a11y|accessib\w*|tighten|secure|polish)\b/)
          if text.match?(/\b(plan|shape|architect|outline|sketch|wireframe)\b/) &&
             !text.match?(/\b(build|create|make|implement|generate|scaffold|add)\b/)
            return :shape
          end

          :implement
        end

        def route_entry(intent)
          case request_mode(intent)
          when :review then review_route(intent)
          when :harden then harden_route
          when :shape then shape_entry(intent)
          else implement_entry(intent)
          end
        end

        def implement_entry(intent)
          banner = ["GUIDED BUILD - mode: implement.",
                    "Steps: probe -> plan -> direct -> snippets -> verify; each ends with the next call.",
                    "DONE means a PASS from the check tool (an executable verdict), never a claim.", "", ""]
          banner.join("\n") + run_step("probe", intent, {})
        end

        def shape_entry(intent)
          banner = ["GUIDED BUILD - mode: shape (planning only, no host changes).",
                    "You asked to shape, not build - here is the architecture; call step: \"snippets\" " \
                    "when you want source.", "", ""]
          banner.join("\n") + run_step("plan", intent, {})
        end

        def review_route(intent)
          ["REQUEST MODE: review - staying read-only (an audit does not become an edit).",
           "I will not enter the build sequence to review. To assess existing markup:",
           "- run the `check` tool with the ERB source (verdict + findings), or `bin/rails poetry:check`;",
           "- the visual/a11y critique: get_skill(name: \"poetry-design\", file: \"references/audit.md\");",
           "- wrong-component calls: guidance(topic: \"deciding\").", "",
           %(To BUILD instead, re-call with a build verb, e.g. "build #{intent}".)].join("\n")
        end

        def harden_route
          ["REQUEST MODE: harden - read-only recon, no edits from here.",
           "Hardening runs the same executable gate, not a rewrite:",
           "- `check` the current ERB for contract violations (verdict + findings);",
           "- get_skill(name: \"poetry-design\", file: \"references/audit.md\") for the a11y + slop pass;",
           "- fix through tokens/variants/DESIGN.md, never per-instance CSS; re-run check as the LAST action.",
           "", "To build a NEW page instead, re-call with a build verb."].join("\n")
        end

        def run_step(step, intent, arguments)
          case step
          when "probe" then framed(1, "PROBE (host setup)", probe_body, "plan")
          when "plan" then framed(2, "PLAN (page architecture)", plan_body(intent), "direct")
          when "direct" then framed(3, "DIRECT (creative direction)", direct_body, "snippets")
          when "snippets" then framed(4, "SNIPPETS (start-from source)", snippets_body(intent), "verify")
          when "verify" then verify_body(arguments)
          else redirect_step(step)
          end
        end

        def framed(number, label, body, nxt)
          ["STEP #{number}/5 - #{label}", "", body, "",
           %(NEXT -> call build_page again with step: "#{nxt}" (same intent).)].join("\n")
        end

        def redirect_step(step)
          "no such step: #{step.inspect} - the workflow is #{STEPS.join(" -> ")}. " \
            "Omit step for the guided entry, or pass one of those."
        end

        # Step 1: host doctor. Reads what it can from @app_root and degrades
        # gracefully (the plan step never depends on it). Also the JS-channel
        # fail-fast: a bundler present without the controllers channel
        # leaves interactive components inert.
        def probe_body
          root = @app_root
          return probe_no_host unless root && File.directory?(root)

          lines = [host_config_line(root), theme_line(detect_theme(root)), css_mode_line(root)]
          lines.concat(js_pipeline_lines(root))
          lines.join("\n")
        end

        def probe_no_host
          ["Host app not visible (run `bundle exec poetry-agent` from the app dir for setup checks).",
           "Probe would read: installed components + declared overrides (config/poetry_components.yml),",
           "the installed theme, css_mode, icon set, and importmap-vs-bundler. Assume a standard",
           "poetry install and continue - the plan step does not depend on this."].join("\n")
        end

        def host_config_line(root)
          cfg = read_host_yaml(File.join(root, "config", "poetry_components.yml"))
          return "poetry config: config/poetry_components.yml not found - run `bin/rails g poetry:install`." unless cfg

          installed = (cfg["components"] || {}).size
          overrides = (cfg["overrides"] || {}).size
          "poetry config: #{installed} component(s) configured, #{overrides} declared cn-* override(s)."
        end

        def theme_line(theme)
          return "theme: not detected - the direct step covers picking one of the nine." unless theme

          "theme: #{theme} (its tokens ARE your creative direction - step 3)."
        end

        def css_mode_line(root)
          entry = ["app/assets/tailwind/application.css", "tailwind.config.js", "config/tailwind.config.js",
                   "app/assets/stylesheets/application.tailwind.css"].any? { |rel| host_exist?(root, rel) }
          if entry
            "css_mode: Tailwind entry found - poetry emits Tailwind classes."
          else
            "css_mode: no Tailwind entry detected - poetry can emit raw BEM when css_mode is set."
          end
        end

        def js_pipeline_lines(root)
          importmap = host_exist?(root, "config/importmap.rb")
          bundler = %w[vite.config.js vite.config.ts config/vite.json package.json].any? do |rel|
            host_exist?(root, rel)
          end
          if importmap && !bundler
            ["js: importmap - pin poetry's Stimulus controllers so interactive components wire up."]
          elsif bundler
            ["js: a JS bundler is present - poetry's controllers need the @poetry/controllers npm channel",
             "wired, or the interactive components stay inert. Verify the import."]
          else
            ["js: no importmap or bundler detected - poetry's interactive components need one wired."]
          end
        end

        # Step 2: the intent-matched page architecture (the new IP). Same
        # stem tokenization + weighting as the block router, so plan and
        # compose rank an intent the same way.
        def plan_body(intent)
          tokens = brief_tokens(intent)
          scored = PageArchitectures.scored(tokens)
          best, best_score = scored.first
          return no_archetype(scored) if best.nil? || best_score < ARCHETYPE_MATCH

          [render_archetype(best, best_score), runners_note(scored)].reject(&:empty?).join("\n")
        end

        def render_archetype(entry, score)
          lines = ["MATCH: #{entry["title"]} (`#{entry["name"]}`) - score #{score}.", entry["purpose"], "",
                   start_from(entry), "", "Section order:"]
          entry["sections"].each { |section| lines << "- #{section}" }
          lines << ""
          lines << "States a real screen handles (not just the happy path):"
          entry["states"].each { |state| lines << "- #{state}" }
          lines << ""
          lines << "Edge cases that bite:"
          entry["edge_cases"].each { |edge| lines << "- #{edge}" }
          lines << ""
          lines << "Components: #{entry["components"].join(", ")} (describe_component for the contracts)."
          lines.join("\n")
        end

        def start_from(entry)
          if entry["block"]
            "Start from block `#{entry["block"]}` - describe_block returns its source; adapt in place " \
              "(the known winning path). Fill gaps with the components below."
          else
            "No single vetted block covers this yet - compose from the components below, applying the " \
              "section order and the five mechanics (get_skill poetry-design references/compose.md)."
          end
        end

        def runners_note(scored)
          runners = scored.drop(1).select { |_entry, score| score.positive? }.first(2)
          return "" if runners.empty?

          described = runners.map { |entry, score| "`#{entry["name"]}` (#{entry["title"]}, score #{score})" }
          "\nNearby archetypes: #{described.join(", ")}."
        end

        def no_archetype(scored)
          near = scored.first(3).map { |entry, _score| entry["name"] }.join(", ")
          ["No archetype strongly matched this intent. The catalog is a SEED " \
           "(#{PageArchitectures.all.size} archetypes; it grows toward the ~50 target).",
           "Fall back to `compose` for block/component routing, and the five composition mechanics " \
           "(get_skill poetry-design references/compose.md).",
           "Nearest archetypes if one fits: #{near}."].join("\n")
        end

        # Step 3: theme-derived creative direction. poetry's direction is
        # design-system-constrained by construction - it delegates
        # to the authored per-theme vocabulary rather than restating it.
        def direct_body
          theme = @app_root && detect_theme(@app_root)
          lines = ["poetry's creative direction is THEME-DERIVED, not a freeform trend pick: the installed",
                   "theme's typography, radius, motion, and color vocabulary IS the direction. Coherence is",
                   "the product; range comes from the nine themes + a brand DESIGN.md, not per-page CSS.", ""]
          lines << if theme
                     "Installed theme: `#{theme}`. Build inside its vocabulary - its tokens carry the look."
                   else
                     "No theme detected here. Pick one of the nine at install (`--theme`); each is distinct."
                   end
          lines << "Per-theme vocabulary: get_skill(name: \"poetry-design\", file: \"references/theme.md\")."
          lines << if @app_root && design_md_present?(@app_root)
                     "A DESIGN.md is present - it is the brand-override door on top of the theme; honor it."
                   else
                     "No DESIGN.md here - study a brand into one (poetry-design `study`) to override the theme."
                   end
          lines << "Do NOT add gradients, shadows, or arbitrary colors for 'personality' - that is drift."
          lines.join("\n")
        end

        # Step 4: the concrete source, routed exactly as the compose tool
        # (block match inline, or the matching components). compose already
        # closes with "check as the LAST action", which dovetails into verify.
        def snippets_body(intent)
          ["The source to start from (routed like the compose tool):", "", compose("brief" => intent)].join("\n")
        end

        # Step 5: the executable gate. DONE requires a PASS from the same
        # check tool - not an attestation. This is the structural edge over
        # a workflow whose completion is an LLM's word.
        def verify_body(arguments)
          source = arguments["source"].to_s
          if source.strip.empty?
            return ["STEP 5/5 - VERIFY (the executable gate)", "",
                    "Pass your built ERB as `source` to run check here, or run `bin/rails poetry:check`.",
                    "The workflow is DONE only on a PASS - an edit after your last check is unverified.",
                    %(When ready: build_page(intent: "...", step: "verify", source: "<your ERB>").)].join("\n")
          end

          report = check("source" => source)
          header = if report.start_with?("PASS")
                     "STEP 5/5 - VERIFY: PASS - the guided build is DONE."
                   else
                     "STEP 5/5 - VERIFY: FAIL - not done. Fix the findings and re-run verify."
                   end
          [header, "", report].join("\n")
        end

        # --- host-file probes (best-effort, always graceful) ---

        def read_host_yaml(path)
          return nil unless File.file?(path)

          require "yaml"
          YAML.safe_load_file(path, permitted_classes: [Symbol], aliases: true)
        rescue StandardError
          nil
        end

        # Header sniff for the installed theme: the `.style-<name>` scope the
        # docs switcher uses, or a `poetry theme: <name>` marker. First 4KB
        # is enough; any read error just means "not detected".
        def detect_theme(root)
          %w[app/assets/stylesheets/poetry.css app/assets/stylesheets/application.css
             app/assets/tailwind/application.css app/assets/builds/poetry.css].each do |rel|
            path = File.join(root, rel)
            next unless File.file?(path)

            head = File.read(path, 4096).to_s
            match = head.match(/\bstyle-(#{THEMES.join("|")})\b/) || head.match(/poetry theme:\s*(\w+)/i)
            return match[1] if match
          rescue StandardError
            next
          end
          nil
        end

        def design_md_present?(root)
          %w[DESIGN.md config/DESIGN.md app/assets/DESIGN.md].any? { |rel| host_exist?(root, rel) }
        end

        def host_exist?(root, rel)
          File.exist?(File.join(root, rel))
        end

        def list_blocks
          return "no blocks in this registry" if @blocks.empty?

          @blocks.map do |name, entry|
            "- #{name}: #{entry["title"]} - #{entry["description"]} " \
              "[composes: #{entry["components"].join(", ")}]"
          end.join("\n")
        end

        def list_recipes
          return "no recipes in this registry" if @recipes.empty?

          @recipes.map do |recipe|
            targets = recipe["files"].map { |file| file["target"] }.join(", ")
            "- #{recipe["name"]}: #{recipe["title"]} - #{recipe["description"]} [installs: #{targets}]"
          end.join("\n")
        end

        # Runtime skill delivery: the SAME
        # files `rails g poetry:skill` installs, served over MCP for hosts
        # that cannot write files. SKILL.md alone first - the skill's own
        # progressive-disclosure design; references load one at a time.
        def get_skill(arguments)
          name = arguments["name"] || "poetry"
          loader = @skills[name]
          unless loader
            available = @skills.keys.sort.join(", ")
            listing = available.empty? ? "this host serves none" : "available here: #{available}"
            return "no skill #{name.inspect} - #{listing}. In an app, " \
                   "`bin/rails g poetry:skill` installs them as files instead."
          end

          files = (@skill_files[name] ||= loader.call)
          file = arguments["file"]
          return skill_menu(name, files) unless file

          files.fetch(file) do
            "no file #{file.inspect} in the #{name} skill - files: #{files.keys.sort.join(", ")}"
          end
        end

        def skill_menu(name, files)
          references = files.keys.reject { |path| path == "SKILL.md" }.sort
          menu = ["", "---", "Files in this skill - fetch one with get_skill(name: #{name.inspect}, " \
                             "file: \"...\"):"]
          references.each { |path| menu << "- #{path}" }
          files.fetch("SKILL.md") + menu.join("\n")
        end

        # Curated guidance topics: the same text the installed
        # usage skill carries, reachable when only the MCP is connected.
        def guidance(arguments)
          topic = arguments["topic"].to_s
          topics = { "deciding" => -> { SkillText.deciding_reference } }
          entry = topics[topic]

          return entry.call if entry

          "no such topic: #{topic.inspect} - topics: #{topics.keys.join(", ")}"
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
          (entry["requires_any"] || []).each do |group|
            parts = []
            parts << "a content block" if group["content"]
            parts.concat((group["slots"] || []).map { |name| "with_#{name}" })
            parts.concat((group["options"] || []).map { |key| "#{key}:" })
            lines << "- REQUIRED - one of #{parts.join(" / ")} (#{group["hint"]})"
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
            # The render-crash seams, stated where agents read them.
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
          # The styling contract: every data-slot part with its
          # state attributes and var seams, DOM-verified by the
          # part-contract tier - restyle via [data-slot=...], never by
          # guessing at internal markup.
          (entry["parts"] || []).each { |part| lines << part_line(part) }
          (entry["agent_rules"] || []).each { |rule| lines << "- RULE: #{rule}" }
          lines
        end

        def part_line(part)
          facets = []
          states = (part["states"] || []).map do |state|
            values = state["values"] ? "=#{state["values"].join("|")}" : ""
            "#{state["attr"]}#{values} (#{state["condition"]})"
          end
          facets << "states: #{states.join("; ")}" if states.any?
          vars = (part["vars"] || []).map { |var| "#{var["name"]} (#{var["description"]})" }
          facets << "vars: #{vars.join("; ")}" if vars.any?
          "- part [data-slot=#{part["name"]}] - #{part["description"]}" \
            "#{" | #{facets.join(" | ")}" if facets.any?}"
        end

        def summary(entry)
          return entry["description"] if entry["description"]

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
