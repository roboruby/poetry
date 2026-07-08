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

      def call(name, arguments = {})
        response = server.handle("jsonrpc" => "2.0", "id" => 1, "method" => "tools/call",
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

      def test_tools_list_advertises_the_read_only_tools
        tools = server.handle("id" => 2, "method" => "tools/list").dig("result", "tools")
        names = tools.map { |tool| tool["name"] }

        assert_equal %w[list_components describe_component check], names
        assert(tools.all? { |tool| tool.dig("annotations", "readOnlyHint") })
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
