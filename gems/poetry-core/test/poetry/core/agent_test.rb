# frozen_string_literal: true

require "test_helper"

module Poetry
  module Core
    # poetry-agent: the MCP server. #handle is a pure JSON-RPC
    # request->response function, so the whole protocol surface is tested
    # without stdio. Entries are inline (self-contained); check rides the
    # real controllers manifest via the shared catalog.
    class AgentTest < Minitest::Test
      ENTRIES = {
        "poetry/ui/button" => {
          "class_name" => "Poetry::Ui::Button::Component", "bem_block" => "poetry-ui-button",
          "styles" => [{ "name" => "variant", "type" => "symbol", "variants" => %w[default destructive ghost] }],
          "options" => [{ "name" => "loading", "type" => "boolean" }],
          "slots" => [],
          "parts" => [
            { "name" => "button", "description" => "The control itself",
              "states" => [{ "attr" => "data-loading", "condition" => "loading: is set" }] }
          ],
          "agent_rules" => ["Use poetry_button - never a raw <button>."]
        },
        "poetry/ui/command/dialog" => {
          "class_name" => "Poetry::Ui::Command::DialogComponent", "bem_block" => "poetry-ui-command-dialog",
          "styles" => [], "options" => [{ "name" => "hotkey", "type" => "string" }], "slots" => [],
          "controllers" => [{ "identifier" => "poetry--core--dialog", "targets" => ["dialog"],
                              "values" => %w[hotkey], "actions" => %w[open close toggle] }]
        },
        "poetry/ui/icon" => {
          "class_name" => "Poetry::Ui::Icon::Component", "bem_block" => "poetry-ui-icon",
          "styles" => [],
          "options" => [{ "name" => "name", "type" => "symbol", "required" => true, "format" => "icon-name" }],
          "slots" => []
        },
        "poetry/ui/alert" => {
          "class_name" => "Poetry::Ui::Alert::Component", "bem_block" => "poetry-ui-alert",
          "styles" => [], "options" => [],
          "slots" => [{ "name" => "icon", "many" => false, "component" => "poetry/ui/icon" },
                      { "name" => "title", "many" => false }]
        }
      }.freeze

      HELPER_ENTRIES = {
        "poetry_input_group_addon" => {
          "options" => [{ "name" => "align", "type" => "symbol",
                          "variants" => %w[inline-start inline-end block-start block-end] }]
        }
      }.freeze

      def server
        catalog = Check::Catalog.new(ENTRIES, helper_entries: HELPER_ENTRIES,
                                              icon_names: %w[circle-alert triangle-alert])
        Agent::Server.new(entries: ENTRIES, catalog: catalog)
      end

      BLOCKS = {
        "data-index" => { "title" => "Data index", "description" => "A records screen.",
                          "components" => %w[badge button table],
                          "keywords" => %w[records invoices listing],
                          "template" => "blocks/data_index.html.erb" }
      }.freeze

      BLOCK_TEMPLATE = <<~ERB
        <%# poetry:block title="Data index" description="A records screen." %>
        <section><%= poetry_badge { "Fulfilled" } %></section>
      ERB

      def with_blocks_server
        require "tmpdir"
        Dir.mktmpdir("agent-blocks") do |dir|
          Pathname(dir).join("blocks").mkpath
          Pathname(dir).join("blocks/data_index.html.erb").write(BLOCK_TEMPLATE)
          catalog = Check::Catalog.new(ENTRIES, helper_entries: HELPER_ENTRIES)
          yield Agent::Server.new(entries: ENTRIES, catalog: catalog, blocks: BLOCKS, root: dir)
        end
      end

      def call(name, arguments = {})
        call_on(server, name, arguments)
      end

      def call_on(target, name, arguments = {})
        response = target.handle("jsonrpc" => "2.0", "id" => 1, "method" => "tools/call",
                                 "params" => { "name" => name, "arguments" => arguments })
        response.dig("result", "content", 0, "text")
      end

      # --- protocol ---

      def test_initialize_advertises_protocol_and_server_info
        result = server.handle("id" => 1, "method" => "initialize")["result"]

        assert_equal Agent::PROTOCOL_VERSION, result["protocolVersion"]
        assert_equal "poetry-agent", result.dig("serverInfo", "name")
        assert result.dig("capabilities", "tools")
      end

      def test_tools_list_advertises_the_read_only_tools_compose_first
        tools = server.handle("id" => 2, "method" => "tools/list").dig("result", "tools")
        names = tools.map { |tool| tool["name"] }

        assert_equal %w[compose build_page list_components describe_component check list_blocks
                        describe_block list_recipes get_skill guidance], names
        assert(tools.all? { |tool| tool.dig("annotations", "readOnlyHint") })
        compose = tools.first

        assert_includes compose["description"], "CALL THIS FIRST"
        assert_includes compose["description"], "known losing path"
      end

      # --- compose (the unconditional first move) ---

      def test_compose_routes_a_page_brief_into_the_matching_block_with_source
        with_blocks_server do |blocks_server|
          text = call_on(blocks_server, "compose",
                         "brief" => "An invoices table listing records with totals")

          assert_includes text, "STRONG BLOCK MATCH"
          assert_includes text, "start from `data-index` and adapt it in place"
          assert_includes text, %(<%= poetry_badge { "Fulfilled" } %>), "the source is inline"
          refute_includes text, "poetry:block title=", "the metadata header is stripped"
          assert_includes text, "check tool as the LAST action"
        end
      end

      def test_compose_routes_a_component_brief_to_components_with_the_catalog_visible
        with_blocks_server do |blocks_server|
          text = call_on(blocks_server, "compose", "brief" => "A destructive delete button with an icon")

          assert_includes text, "No block covers this brief"
          assert_includes text, "button (`poetry_button`)"
          assert_includes text, "icon (`poetry_icon`)"
          assert_includes text, "- data-index: Data index", "the catalog stays visible for scale changes"
          assert_includes text, "check tool as the LAST action"
        end
      end

      def test_compose_without_a_brief_asks_for_one_and_lists_the_blocks
        with_blocks_server do |blocks_server|
          text = call_on(blocks_server, "compose")

          assert_includes text, "compose needs the brief text"
          assert_includes text, "data-index"
        end
      end

      def test_compose_scoring_is_stem_deduplicated
        with_blocks_server do |blocks_server|
          # "records record" is ONE stem: 2 points, under the threshold -
          # repetition and plural variants are not signal.
          text = call_on(blocks_server, "compose", "brief" => "records record")

          assert_includes text, "No block covers this brief"
        end
      end

      def test_describe_component_carries_the_block_back_reference
        with_blocks_server do |blocks_server|
          text = call_on(blocks_server, "describe_component", "name" => "button")

          assert_includes text, "in blocks: data-index"
          assert_includes text, "start there (describe_block), not from scratch"
        end
        refute_includes call("describe_component", "name" => "button"), "in blocks:",
                        "a blockless registry adds no back-reference"
      end

      # --- the blocks surface ---

      def test_list_blocks_teaches_the_catalog_and_empty_registries_say_so
        with_blocks_server do |blocks_server|
          text = call_on(blocks_server, "list_blocks")

          assert_includes text, "- data-index: Data index - A records screen. [composes: badge, button, table]"
        end
        assert_includes call("list_blocks"), "no blocks in this registry"
      end

      def test_list_recipes_teaches_the_channel_and_empty_registries_say_so
        recipes = [{ "name" => "skill-poetry", "title" => "poetry skill bundle",
                     "description" => "The component-usage skill.",
                     "files" => [{ "path" => "SKILL.md", "target" => ".claude/skills/poetry/SKILL.md" }] }]
        catalog = Check::Catalog.new(ENTRIES, helper_entries: HELPER_ENTRIES)
        server = Agent::Server.new(entries: ENTRIES, catalog: catalog, recipes: recipes)
        text = call_on(server, "list_recipes")

        assert_includes text, "- skill-poetry: poetry skill bundle - The component-usage skill."
        assert_includes text, "[installs: .claude/skills/poetry/SKILL.md]"

        assert_includes call("list_recipes"), "no recipes in this registry"
      end

      def test_describe_block_inlines_the_source_without_the_metadata_header
        with_blocks_server do |blocks_server|
          text = call_on(blocks_server, "describe_block", "name" => "data_index")

          assert_includes text, "# Data index (`data-index`)", "underscored names normalize"
          assert_includes text, "bin/rails g poetry:block data-index"
          assert_includes text, %(<%= poetry_badge { "Fulfilled" } %>)
          refute_includes text, "poetry:block title=", "the metadata header is stripped"
        end
      end

      def test_describe_block_unknown_name_points_at_list_blocks
        with_blocks_server do |blocks_server|
          assert_includes call_on(blocks_server, "describe_block", "name" => "nope"),
                          "no such block"
        end
      end

      # --- build_page (the guided page workflow) ---

      # A server with BOTH a blocks registry (for the snippets step) and a
      # host app_root (for probe/direct): a fake config, an importmap, a
      # Tailwind entry, and a theme-scoped CSS header.
      def with_build_server
        require "tmpdir"
        Dir.mktmpdir("agent-build") do |dir|
          root = Pathname(dir).join("registry")
          app = Pathname(dir).join("app")
          root.join("blocks").mkpath
          root.join("blocks/data_index.html.erb").write(BLOCK_TEMPLATE)
          app.join("config").mkpath
          app.join("config/poetry_components.yml").write(<<~YML)
            components:
              button: {}
              table: {}
            overrides:
              cn-card: { reason: "brand" }
          YML
          app.join("config/importmap.rb").write("pin \"application\"\n")
          app.join("app/assets/stylesheets").mkpath
          app.join("app/assets/stylesheets/poetry.css").write("/* poetry theme: vega */\n.style-vega {}\n")
          app.join("app/assets/tailwind").mkpath
          app.join("app/assets/tailwind/application.css").write("@import \"tailwindcss\";\n")
          catalog = Check::Catalog.new(ENTRIES, helper_entries: HELPER_ENTRIES,
                                                icon_names: %w[circle-alert triangle-alert])
          yield Agent::Server.new(entries: ENTRIES, catalog: catalog, blocks: BLOCKS,
                                  root: root.to_s, app_root: app.to_s)
        end
      end

      def test_build_page_needs_an_intent
        assert_includes call("build_page", "step" => "plan"), "build_page needs the intent"
      end

      def test_build_page_entry_routes_a_build_verb_into_the_probe_step
        # No app_root on the plain server: probe degrades, the sequence still starts.
        text = call("build_page", "intent" => "build a records index for invoices")

        assert_includes text, "mode: implement"
        assert_includes text, "STEP 1/5 - PROBE"
        assert_includes text, "Host app not visible", "probe degrades without a host"
        assert_includes text, %(step: "plan"), "it routes to the next step"
      end

      def test_build_page_probe_reads_the_host_when_present
        with_build_server do |target|
          text = call_on(target, "build_page", "intent" => "build a dashboard", "step" => "probe")

          assert_includes text, "2 component(s) configured, 1 declared cn-* override"
          assert_includes text, "theme: vega"
          assert_includes text, "Tailwind entry found"
          assert_includes text, "importmap"
          assert_includes text, %(step: "plan")
        end
      end

      def test_build_page_plan_matches_an_archetype_with_states_and_edge_cases
        text = call("build_page", "intent" => "a dashboard overview for the admin workspace",
                                  "step" => "plan")

        assert_includes text, "MATCH: Admin dashboard"
        assert_includes text, "`admin-dashboard`"
        assert_includes text, "Start from block `app-shell`"
        assert_includes text, "Section order:"
        assert_includes text, "States a real screen handles"
        assert_includes text, "Edge cases that bite:"
        assert_includes text, %(step: "direct")
      end

      def test_build_page_plan_falls_back_to_the_seed_note_when_nothing_matches
        text = call("build_page", "intent" => "xyzzy plugh frobnicate", "step" => "plan")

        assert_includes text, "No archetype strongly matched"
        assert_includes text, "SEED"
        assert_includes text, "compose"
      end

      def test_build_page_direct_is_theme_derived_and_delegates_the_vocabulary
        with_build_server do |target|
          text = call_on(target, "build_page", "intent" => "a settings page", "step" => "direct")

          assert_includes text, "THEME-DERIVED"
          assert_includes text, "Installed theme: `vega`"
          assert_includes text, "references/theme.md"
          assert_includes text, "No DESIGN.md here"
          assert_includes text, %(step: "snippets")
        end
      end

      def test_build_page_snippets_routes_source_like_compose
        with_build_server do |target|
          text = call_on(target, "build_page",
                         "intent" => "An invoices table listing records with totals", "step" => "snippets")

          assert_includes text, "STRONG BLOCK MATCH", "snippets reuses the compose router"
          assert_includes text, %(<%= poetry_badge { "Fulfilled" } %>), "the block source is inline"
          assert_includes text, %(step: "verify")
        end
      end

      def test_build_page_verify_is_the_executable_gate
        pass = call("build_page", "intent" => "x", "step" => "verify",
                                  "source" => %(<%= poetry_button(variant: :ghost) { "x" } %>))
        fail_ = call("build_page", "intent" => "x", "step" => "verify",
                                   "source" => %(<%= poetry_button(variant: :nope) { "x" } %>))
        no_source = call("build_page", "intent" => "x", "step" => "verify")

        assert_includes pass, "PASS - the guided build is DONE"
        assert_includes fail_, "FAIL - not done"
        assert_includes fail_, "not a poetry_button variant"
        assert_includes no_source, "Pass your built ERB as `source`"
      end

      def test_build_page_review_and_harden_verbs_stay_read_only
        review = call("build_page", "intent" => "review this dashboard for issues")
        harden = call("build_page", "intent" => "harden the a11y of this settings page")

        assert_includes review, "REQUEST MODE: review"
        assert_includes review, "an audit does not become an edit"
        refute_includes review, "STEP 1/5", "a review never enters the build sequence"
        assert_includes harden, "REQUEST MODE: harden"
        assert_includes harden, "read-only recon"
      end

      def test_build_page_shape_verb_plans_without_probing
        text = call("build_page", "intent" => "plan the architecture of a pricing page")

        assert_includes text, "mode: shape"
        assert_includes text, "STEP 2/5 - PLAN"
        assert_includes text, "pricing"
        refute_includes text, "STEP 1/5 - PROBE", "shape skips probe"
      end

      def test_build_page_rejects_an_unknown_step
        assert_includes call("build_page", "intent" => "x", "step" => "frobnicate"), "no such step"
      end

      def test_a_notification_gets_no_reply
        assert_nil server.handle("method" => "notifications/initialized")
      end

      def test_an_unknown_method_is_a_json_rpc_error
        response = server.handle("id" => 9, "method" => "nonsense")

        assert_equal(-32_601, response.dig("error", "code"))
      end

      # --- list_components ---

      def test_list_components_names_helpers_and_flags_interactive
        text = call("list_components")

        assert_includes text, "button (`poetry_button`)"
        # command/dialog is addressed by full path and flagged interactive.
        assert_includes text, "command_dialog (`poetry_command_dialog`) [interactive]"
        refute_includes text, "button (`poetry_button`) [interactive]"
      end

      # --- describe_component (progressive disclosure) ---

      def test_describe_brief_is_just_the_summary
        text = call("describe_component", "name" => "button", "detail" => "brief")

        assert_includes text, "# button (`poetry_button`)"
        assert_includes text, "default|destructive|ghost"
        refute_includes text, "loading" # options only appear at detailed+
      end

      def test_describe_detailed_adds_options_and_variants
        text = call("describe_component", "name" => "button", "detail" => "detailed")

        assert_includes text, "loading: boolean"
        refute_includes text, "RULE:" # rules only at full
      end

      def test_describe_full_adds_wiring_and_rules
        text = call("describe_component", "name" => "command_dialog", "detail" => "full")

        assert_includes text, "wiring poetry--core--dialog: actions open, close, toggle"
      end

      # The styling contract at full detail: parts with their state
      # attributes, phrased as the selector agents actually target.
      def test_describe_full_adds_the_part_contract
        text = call("describe_component", "name" => "button", "detail" => "full")

        assert_includes text,
                        "part [data-slot=button] - The control itself | states: data-loading (loading: is set)"
      end

      def test_describe_full_carries_agent_rules
        assert_includes call("describe_component", "name" => "button", "detail" => "full"), "RULE: Use poetry_button"
      end

      def test_describe_an_unknown_component_guides_to_the_list
        assert_includes call("describe_component", "name" => "buton"), "no such component"
      end

      # --- check (verdict-returning) ---

      def test_check_passes_clean_source
        assert_includes call("check", "source" => %(<%= poetry_button(variant: :ghost) { "x" } %>)), "PASS"
      end

      def test_check_fails_and_reports_findings
        text = call("check", "source" => %(<%= poetry_button(variant: :nope) { "x" } %>))

        assert_includes text, "FAIL"
        assert_includes text, "not a poetry_button variant"
      end

      def test_describe_marks_typed_slots_and_value_contracts
        icon = call("describe_component", "name" => "icon", "detail" => "detailed")
        alert = call("describe_component", "name" => "alert", "detail" => "detailed")

        assert_includes icon, "name: symbol (required; format: icon-name)"
        assert_includes alert, "icon (takes poetry_icon props, not a block)"
        assert_includes alert, "title"
      end

      def test_check_catches_the_value_contract_crash_classes
        block_slot = call("check", "source" => <<~ERB)
          <%= poetry_alert do |alert| %>
            <% alert.with_icon do %><%= poetry_icon(name: :triangle_alert) %><% end %>
          <% end %>
        ERB
        bad_align = call("check", "source" => %(<%= poetry_input_group_addon(align: :leading) { "@" } %>))

        assert_includes block_slot, "FAIL"
        assert_includes block_slot, "not a block"
        assert_includes block_slot, %(name: "triangle_alert" is not an icon name)
        assert_includes bad_align, "FAIL"
        assert_includes bad_align, "inline-start, inline-end, block-start, block-end"
      end

      # --- get_skill (runtime skill delivery) ---

      SKILL_FIXTURE = {
        "SKILL.md" => "# poetry - component usage\nGuardrails here.",
        "references/forms.md" => "# forms contracts",
        "references/deciding.md" => "# deciding"
      }.freeze

      def skills_server
        loads = 0
        counter = -> { loads }
        skills = { "poetry" => lambda {
          loads += 1
          SKILL_FIXTURE
        } }
        catalog = Check::Catalog.new(ENTRIES, helper_entries: HELPER_ENTRIES)
        [Agent::Server.new(entries: ENTRIES, catalog: catalog, skills: skills), counter]
      end

      def test_get_skill_serves_skill_md_with_the_file_index
        target, = skills_server
        text = call_on(target, "get_skill")

        assert_includes text, "# poetry - component usage"
        assert_includes text, "references/forms.md"
        assert_includes text, "get_skill(name: \"poetry\", file:"
      end

      def test_get_skill_fetches_one_reference_and_memoizes_generation
        target, loads = skills_server
        first = call_on(target, "get_skill", "name" => "poetry", "file" => "references/forms.md")
        call_on(target, "get_skill", "file" => "references/deciding.md")

        assert_equal "# forms contracts", first
        assert_equal 1, loads.call, "the file map is generated once, then served from memory"
      end

      def test_get_skill_names_what_is_missing
        target, = skills_server
        no_skill = call_on(target, "get_skill", "name" => "poetry-design")
        no_file = call_on(target, "get_skill", "file" => "references/vibes.md")
        bare = call("get_skill")

        assert_includes no_skill, 'no skill "poetry-design"'
        assert_includes no_skill, "available here: poetry"
        assert_includes no_file, 'no file "references/vibes.md"'
        assert_includes no_file, "references/forms.md"
        assert_includes bare, "this host serves none"
        assert_includes bare, "bin/rails g poetry:skill"
      end

      def test_guidance_serves_the_deciding_tree_and_names_unknown_topics
        deciding = call("guidance", "topic" => "deciding")
        unknown = call("guidance", "topic" => "vibes")

        assert_includes deciding, "INTERACTION MODEL"
        assert_includes deciding, "never a menu"
        assert_includes unknown, "no such topic"
        assert_includes unknown, "deciding"
      end

      # --- stdio framing ---

      def test_serve_reads_ndjson_and_writes_replies
        input = StringIO.new(%({"id":1,"method":"tools/list"}\n\n))
        output = StringIO.new
        server.serve(input: input, output: output)

        assert_includes output.string, %("name":"list_components")
      end

      def test_serve_survives_a_malformed_line
        input = StringIO.new(%(not json\n{"id":1,"method":"tools/list"}\n))
        output = StringIO.new
        server.serve(input: input, output: output)

        assert_includes output.string, "parse error" # the bad line
        assert_includes output.string, "list_components" # the loop kept going
      end
    end
  end
end
