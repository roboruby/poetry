# frozen_string_literal: true

require "test_helper"
require "rack/test"
require "poetry/ui"

module Poetry
  module Agent
    # The HTTP transport over the same pure Server#handle the exe serves:
    # POST JSON-RPC in, JSON out, same-origin only, read-only by construction.
    class MCPHTTPTest < Minitest::Test
      include Rack::Test::Methods

      def app
        @app ||= MCP::HTTP.new(-> { MCP::Bundled.server(app_root: Dir.pwd) })
      end

      def rpc(method, params = {}, id: 1)
        post "/", JSON.generate({ "jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params }),
             "CONTENT_TYPE" => "application/json"
        JSON.parse(last_response.body)
      end

      def test_initialize_and_tools_list_over_http
        reply = rpc("initialize")

        assert_predicate last_response, :ok?
        assert_equal "application/json", last_response.content_type
        assert_equal "poetry-agent", reply.dig("result", "serverInfo", "name")

        names = rpc("tools/list").dig("result", "tools").map { |tool| tool["name"] }

        assert_includes names, "describe_component"
        assert_includes names, "check"
      end

      def test_tools_call_reaches_the_registry
        text = rpc("tools/call", { "name" => "describe_component", "arguments" => { "name" => "tabs", "detail" => "full" } })
               .dig("result", "content", 0, "text")

        assert_includes text, "poetry_tabs"
        assert_includes text, "- tool set_value", "the operate surface reaches HTTP clients too"
      end

      def test_batches_and_notifications
        post "/", JSON.generate([
                                  { "jsonrpc" => "2.0", "id" => 1, "method" => "initialize", "params" => {} },
                                  { "jsonrpc" => "2.0", "method" => "notifications/initialized" }
                                ]), "CONTENT_TYPE" => "application/json"

        assert_predicate last_response, :ok?
        assert_equal([1], JSON.parse(last_response.body).map { |reply| reply["id"] })

        post "/", JSON.generate({ "jsonrpc" => "2.0", "method" => "notifications/initialized" }),
             "CONTENT_TYPE" => "application/json"

        assert_equal 202, last_response.status
      end

      def test_only_post_and_only_same_origin
        get "/"

        assert_equal 405, last_response.status
        assert_equal "POST", last_response.headers["allow"]

        post "/", JSON.generate({ "jsonrpc" => "2.0", "id" => 1, "method" => "initialize" }),
             "CONTENT_TYPE" => "application/json", "HTTP_ORIGIN" => "https://evil.example"

        assert_equal 403, last_response.status

        post "/", JSON.generate({ "jsonrpc" => "2.0", "id" => 1, "method" => "initialize" }),
             "CONTENT_TYPE" => "application/json", "HTTP_ORIGIN" => "http://example.org"

        assert_predicate last_response, :ok?, "Rack::Test's own host passes as same-origin"
      end

      def test_malformed_json_is_a_parse_error_not_a_crash
        post "/", "{not json", "CONTENT_TYPE" => "application/json"

        assert_equal 400, last_response.status
        assert_equal(-32_700, JSON.parse(last_response.body).dig("error", "code"))
      end
    end
  end
end
