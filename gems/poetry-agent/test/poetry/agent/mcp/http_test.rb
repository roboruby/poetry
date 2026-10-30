# frozen_string_literal: true

require "test_helper"
require "rack/test"
require "poetry/ui"

module Poetry
  module Agent
    # The HTTP transport (the gem's, stateless and JSON-answering) over the
    # same server the exe serves: POST JSON-RPC in, JSON out, same-origin
    # only, read-only by construction.
    class MCPHTTPTest < Minitest::Test
      include Rack::Test::Methods

      INITIALIZE = { "protocolVersion" => MCP::PROTOCOL_VERSION, "capabilities" => {},
                     "clientInfo" => { "name" => "test", "version" => "0" } }.freeze

      def app
        @app ||= MCP::HTTP.new(-> { MCP::Bundled.server(app_root: Dir.pwd) })
      end

      def rpc(method, params = {}, id: 1)
        post "/", JSON.generate({ "jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params }),
             "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json"
        JSON.parse(last_response.body)
      end

      def test_initialize_and_tools_list_over_http
        reply = rpc("initialize", INITIALIZE)

        assert_predicate last_response, :ok?
        assert_equal "application/json", last_response.content_type
        assert_equal "poetry-agent", reply.dig("result", "serverInfo", "name")

        names = rpc("tools/list").dig("result", "tools").map { |tool| tool["name"] }

        assert_includes names, "describe_component"
        assert_includes names, "check"
      end

      def test_tools_call_reaches_the_registry
        arguments = { "name" => "tabs", "detail" => "full" }
        text = rpc("tools/call", { "name" => "describe_component", "arguments" => arguments })
               .dig("result", "content", 0, "text")

        assert_includes text, "poetry_tabs"
        assert_includes text, "- tool set_value", "the operate surface reaches HTTP clients too"
      end

      def test_notifications_are_accepted_and_batches_refused
        post "/", JSON.generate({ "jsonrpc" => "2.0", "method" => "notifications/initialized" }),
             "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json"

        assert_equal 202, last_response.status

        post "/", JSON.generate([
                                  { "jsonrpc" => "2.0", "id" => 1, "method" => "initialize", "params" => INITIALIZE },
                                  { "jsonrpc" => "2.0", "method" => "notifications/initialized" }
                                ]), "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json"

        assert_equal 400, last_response.status, "the protocol dropped batches in 2025-06-18"
        assert_equal(-32_600, JSON.parse(last_response.body).dig("error", "code"))
      end

      def test_only_post_and_only_same_origin
        get "/", {}, "HTTP_ACCEPT" => "text/event-stream"

        assert_equal 405, last_response.status, "stateless: no stream to open"

        post "/", JSON.generate({ "jsonrpc" => "2.0", "id" => 1, "method" => "initialize", "params" => INITIALIZE }),
             "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json",
             "HTTP_ORIGIN" => "https://evil.example"

        assert_equal 403, last_response.status

        post "/", JSON.generate({ "jsonrpc" => "2.0", "id" => 1, "method" => "initialize", "params" => INITIALIZE }),
             "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json",
             "HTTP_ORIGIN" => "http://example.org"

        assert_predicate last_response, :ok?, "Rack::Test's own host passes as same-origin"

        post "/", JSON.generate({ "jsonrpc" => "2.0", "id" => 1, "method" => "initialize", "params" => INITIALIZE }),
             "CONTENT_TYPE" => "application/json", "HTTP_ORIGIN" => "https://docs.example"

        assert_equal 403, last_response.status

        allowed = MCP::HTTP.new(-> { MCP::Bundled.server(app_root: Dir.pwd) }, allowed_origins: ["https://docs.example"])
        body = JSON.generate({ "jsonrpc" => "2.0", "id" => 1, "method" => "initialize", "params" => INITIALIZE })
        env = Rack::MockRequest.env_for("/", method: "POST", input: body, "CONTENT_TYPE" => "application/json",
                                             "HTTP_ACCEPT" => "application/json",
                                             "HTTP_ORIGIN" => "https://docs.example")
        status, = allowed.call(env)

        assert_equal 200, status, "an allow-listed origin passes"
      end

      def test_malformed_json_is_a_parse_error_not_a_crash
        post "/", "{not json", "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json"

        assert_equal 400, last_response.status
        assert_equal(-32_700, JSON.parse(last_response.body).dig("error", "code"))
      end
    end
  end
end
