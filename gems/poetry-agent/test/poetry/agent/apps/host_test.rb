# frozen_string_literal: true

require "test_helper"
require "action_controller"
require "rack/mock"
require "json"

module Poetry
  module Agent
    # The host side of MCP Apps: a host over its servers, its client against
    # Poetry's own MCP server in process, the caches, the visibility
    # allowlist, the sandbox page with its policy, the RPC endpoint and the
    # frame's data.
    class AppsHostTest < Minitest::Test
      ORIGIN = "https://chat.example"
      APPS = "https://apps.chat.example"

      # A renderer that answers a marker page.
      class FakeRenderer
        def render(**options) = "<html><body data-template='#{options[:template]}'>app</body></html>"
      end

      # A server with one app: a model tool and an app-only tool on the same document.
      def server
        @server ||= begin
          document = Apps::Document.new(uri: "ui://shop/plans", name: "plans", template: "apps/plans", origin: "https://shop.example",
                                        renderer: FakeRenderer.new, prefers_border: true, connect: ["https://api.example"])
          MCP::Bundled.server(app_root: Dir.pwd).apps(document).tap do |held|
            schema = { type: "object", properties: { team_size: { type: "integer" } } }
            held.mcp.define_tool(name: "show_plans", description: "Plans", input_schema: schema,
                                 meta: document.tool_meta) do |team_size: nil, **|
              Apps.result(text: "plans for #{team_size}", data: { "team_size" => team_size }).to_response
            end
            app_only = document.tool_meta(visibility: ["app"])
            held.mcp.define_tool(name: "choose_plan", description: "Choose", input_schema: { type: "object" },
                                 meta: app_only) { |**| Apps.result(text: "chosen").to_response }
            model_only = document.tool_meta(visibility: ["model"])
            held.mcp.define_tool(name: "secret", description: "Model only", input_schema: { type: "object" },
                                 meta: model_only) { |**| Apps.result(text: "secret").to_response }
          end
        end
      end

      # The transport seam: the server's Rack app in process, recording every request's headers.
      def post
        @posts = []
        app = MCP::HTTP.new(server)
        lambda do |uri, body, headers|
          @posts << { uri: uri.to_s, body: JSON.parse(body), headers: headers }
          env = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => headers["Accept"], input: body }
          env["HTTP_AUTHORIZATION"] = headers["Authorization"] if headers["Authorization"]
          response = Rack::MockRequest.new(app).post("/", env)
          [response.status, response.headers.to_h, response.body]
        end
      end

      def host(**)
        Apps::Host.new(servers: { "shop" => { url: "https://shop.example/mcp", headers: { "X-Shop" => "yes" } } },
                       origin: ORIGIN, sandbox_origin: APPS, secret: "s3cret", **).tap { |held| held.post = post }
      end

      # --- the registry and the client ---

      def test_a_server_is_known_by_id_and_the_client_connects_with_the_extension_declared
        subject = host
        client = subject.client("shop", headers: { "Authorization" => "Bearer alice" })

        assert_predicate client, :connected?
        assert_equal "poetry-agent", client.server_info["name"]
        assert_includes client.server_capabilities["extensions"].keys, ::MCP::Apps::EXTENSION_ID
        initialize = @posts.first

        assert_equal "initialize", initialize[:body]["method"]
        assert_equal({ "io.modelcontextprotocol/ui" => { "mimeTypes" => ["text/html;profile=mcp-app"] } },
                     initialize[:body].dig("params", "capabilities", "extensions"))
        assert_equal "yes", initialize[:headers]["X-Shop"], "the server's own headers ride every request"
        assert_equal "Bearer alice", initialize[:headers]["Authorization"], "and the request's headers over them"
        assert_equal "notifications/initialized", @posts[1][:body]["method"]
        assert_raises(Apps::Host::Refused) { subject.server("other") }
      end

      def test_the_client_reads_an_event_stream_answer_and_raises_the_server_s_error
        answers = lambda do |_uri, body, _headers|
          message = JSON.parse(body)
          next [202, {}, ""] unless message["id"]

          frame = JSON.generate({ "jsonrpc" => "2.0", "id" => message["id"],
                                  "result" => { "pong" => message["method"] } })
          [200, { "content-type" => "text/event-stream", "mcp-session-id" => "s1" },
           "event: message\ndata: #{frame}\n\n"]
        end
        client = Apps::Host::Client.new(url: "https://sse.example/mcp", post: answers)

        assert_equal({ "pong" => "ping" }, client.ping)
        refusing = lambda do |_uri, body, _headers|
          error = { "jsonrpc" => "2.0", "id" => JSON.parse(body)["id"],
                    "error" => { "code" => -32_601, "message" => "nope" } }
          [200, { "content-type" => "application/json" }, JSON.generate(error)]
        end
        error = assert_raises(Apps::Host::Client::Error) { Apps::Host::Client.new(url: "https://x.example/mcp", post: refusing).ping }

        assert_equal(-32_601, error.code)
        failing = ->(*) { [503, {}, ""] }

        assert_raises(Apps::Host::Client::Error) { Apps::Host::Client.new(url: "https://x.example/mcp", post: failing).ping }
      end

      # --- tools, visibility, resources, calls ---

      def test_the_tools_carry_their_app_metadata_and_the_visibility_rules_follow_it
        subject = host
        tools = subject.tools("shop")
        plans = tools.find { |tool| tool[:name] == "show_plans" }

        assert_equal "ui://shop/plans", plans[:resource_uri]
        assert_nil plans[:visibility]
        assert_equal ["app"], tools.find { |tool| tool[:name] == "choose_plan" }[:visibility]
        assert subject.app_callable?("shop", "show_plans"), "no visibility declared means both"
        assert subject.app_callable?("shop", "choose_plan")
        refute subject.app_callable?("shop", "secret")
        assert subject.model_visible?("shop", "show_plans")
        refute subject.model_visible?("shop", "choose_plan")
        refute subject.app_callable?("shop", "unknown")
        posts = @posts.size
        subject.tools("shop")

        assert_equal posts, @posts.size, "the tool list is cached"
      end

      def test_a_resource_is_read_once_with_its_policy_and_a_call_knows_its_app
        subject = host
        resource = subject.resource("shop", "ui://shop/plans")

        assert_includes resource.html, "data-template='apps/plans'"
        assert_equal({ "connectDomains" => ["https://shop.example", "https://api.example"],
                       "resourceDomains" => ["https://shop.example"] }, resource.ui["csp"])
        assert resource.ui["prefersBorder"]
        posts = @posts.size

        assert_same resource, subject.resource("shop", "ui://shop/plans")
        assert_equal posts, @posts.size, "the resource is cached"
        subject.clear_cache

        refute_same resource, subject.resource("shop", "ui://shop/plans")
        assert_operator @posts.size, :>, posts, "a cleared cache reads the resource again"
        assert_raises(Apps::Host::Refused) { subject.resource("shop", "ui://shop/none") }
        call = subject.call("shop", "show_plans", { "team_size" => 8 })

        assert_predicate call, :app?
        assert_equal "ui://shop/plans", call.resource_uri
        assert_equal "plans for 8", call.result.dig("content", 0, "text")
        assert_equal({ "team_size" => 8 }, call.result["structuredContent"])
        assert_raises(Apps::Host::Refused) { subject.call("shop", "choose_plan") }
      end

      def test_an_app_s_request_goes_through_the_allowlist_and_the_visibility_check
        subject = host

        assert_equal "chosen",
                     subject.rpc("shop", "tools/call", { "name" => "choose_plan", "arguments" => {} }).dig("content",
                                                                                                           0, "text")
        assert_equal({}, subject.rpc("shop", "ping"))
        assert_equal({ "success" => true },
                     subject.rpc("shop", "notifications/message", { "level" => "info", "data" => "x" }))
        assert_equal "ui://shop/plans",
                     subject.rpc("shop", "resources/read", { "uri" => "ui://shop/plans" }).dig("contents", 0, "uri")
        refused = assert_raises(Apps::Host::Refused) { subject.rpc("shop", "tools/call", { "name" => "secret" }) }

        assert_equal(-32_602, refused.code)
        refused = assert_raises(Apps::Host::Refused) { subject.rpc("shop", "tools/list") }

        assert_equal(-32_601, refused.code)
      end

      # --- the sandbox ---

      def test_a_sandbox_token_names_a_resource_and_the_page_serves_it_under_its_policy
        subject = host
        token = subject.sandbox_token("shop", "ui://shop/plans")

        assert_equal({ "server" => "shop", "uri" => "ui://shop/plans" }, subject.verify_sandbox_token(token))
        assert_nil subject.verify_sandbox_token("#{token}x")
        assert_nil subject.verify_sandbox_token(host(secret: "other").sandbox_token("shop", "ui://shop/plans"))
        assert_equal "#{APPS}/mcp-apps/sandbox/#{token}", subject.sandbox_url("shop", "ui://shop/plans")
        response = Rack::MockRequest.new(subject.sandbox_app).get("/#{token}")

        assert_equal 200, response.status
        assert_equal "text/html; charset=utf-8", response.headers["content-type"]
        assert_equal "no-store", response.headers["cache-control"]
        assert_nil response.headers["x-frame-options"]
        policy = response.headers["content-security-policy"]

        assert_includes policy, "connect-src 'self' https://shop.example https://api.example"
        assert_includes policy, "script-src 'self' 'unsafe-inline' 'unsafe-eval' blob: https://shop.example"
        assert_includes policy, "frame-ancestors #{ORIGIN}"
        assert_includes response.body, %(const HOST_ORIGIN = "#{ORIGIN}")
        assert_includes response.body, "allow-scripts allow-same-origin allow-forms"
        assert_includes response.body, "ui/notifications/sandbox-proxy-ready"
        assert_equal 403, Rack::MockRequest.new(subject.sandbox_app).get("/forged").status
        assert_equal 405, Rack::MockRequest.new(subject.sandbox_app).post("/#{token}").status
        assert_empty Rack::MockRequest.new(subject.sandbox_app).head("/#{token}").body
      end

      def test_the_inline_mode_has_no_apps_origin_and_writes_the_policy_into_the_page
        subject = host(sandbox_origin: nil)

        assert_nil subject.sandbox_url("shop", "ui://shop/plans")
        call = subject.call("shop", "show_plans", {})
        data = subject.frame_data(call)
        page = data["poetry--agent--mcp-app-host-sandbox-page-value"]

        assert_includes page, %(<meta http-equiv="Content-Security-Policy" content="default-src 'none'; )
        refute_includes page, "frame-ancestors", "a meta policy ignores it"
        assert_includes page, %(INNER_SANDBOX = "allow-scripts allow-forms"), "no same-origin inside an opaque frame"
        refute data.key?("poetry--agent--mcp-app-host-sandbox-url-value")
      end

      def test_the_frame_data_carries_the_controller_and_its_values
        subject = host
        call = subject.call("shop", "show_plans", { "team_size" => 8 })
        data = subject.frame_data(call, rpc_url: "/chat/apps/rpc")

        assert_equal "poetry--agent--mcp-app-host", data[:controller]
        assert_equal "shop", data["poetry--agent--mcp-app-host-server-value"]
        assert_equal "show_plans", data["poetry--agent--mcp-app-host-tool-value"]
        assert_equal "ui://shop/plans", data["poetry--agent--mcp-app-host-resource-value"]
        assert_equal({ "team_size" => 8 }, JSON.parse(data["poetry--agent--mcp-app-host-input-value"]))
        assert_equal "plans for 8",
                     JSON.parse(data["poetry--agent--mcp-app-host-result-value"]).dig("content", 0, "text")
        assert_equal "/chat/apps/rpc", data["poetry--agent--mcp-app-host-rpc-url-value"]
        assert_equal APPS, data["poetry--agent--mcp-app-host-sandbox-origin-value"]
        assert_match %r{\A#{APPS}/mcp-apps/sandbox/}o, data["poetry--agent--mcp-app-host-sandbox-url-value"]
        assert_equal "", data["mcp-app-host"]
      end

      # --- the RPC endpoint ---

      def test_the_rpc_endpoint_answers_same_origin_posts_and_refuses_the_rest
        subject = host
        endpoint = Rack::MockRequest.new(subject.rpc_app)
        request = lambda { |body, **env|
          endpoint.post("/",
                        { "CONTENT_TYPE" => "application/json", "HTTP_SEC_FETCH_SITE" => "same-origin",
                          input: JSON.generate(body) }.merge(env))
        }
        response = request.call({ "server" => "shop", "method" => "tools/call",
                                  "params" => { "name" => "choose_plan" } })

        assert_equal 200, response.status
        assert_equal "chosen", JSON.parse(response.body).dig("result", "content", 0, "text")
        response = request.call({ "server" => "shop", "method" => "tools/call", "params" => { "name" => "secret" } })

        assert_equal 403, response.status
        assert_equal(-32_602, JSON.parse(response.body).dig("error", "code"))
        assert_equal 403,
                     request.call({ "server" => "shop", "method" => "ping" },
                                  "HTTP_SEC_FETCH_SITE" => "cross-site").status
        assert_equal 403,
                     request.call({ "server" => "shop", "method" => "ping" }, "HTTP_SEC_FETCH_SITE" => nil,
                                                                              "HTTP_ORIGIN" => "https://evil.example").status
        assert_equal 200,
                     request.call({ "server" => "shop", "method" => "ping" }, "HTTP_SEC_FETCH_SITE" => nil,
                                                                              "HTTP_ORIGIN" => ORIGIN).status
        assert_equal 400, endpoint.post("/", { "HTTP_SEC_FETCH_SITE" => "same-origin", input: "nope" }).status
        assert_equal 405, endpoint.get("/").status
      end

      def test_the_store_keeps_a_value_until_it_expires
        store = Apps::Host::Store.new
        calls = 0
        twice = -> { store.fetch("k", expires_in: 60) { calls += 1 } }

        assert_equal 1, twice.call
        assert_equal 1, twice.call
        store.fetch("gone", expires_in: 0) { calls += 1 }
        store.fetch("gone", expires_in: 0) { calls += 1 }

        assert_equal 3, calls
        store.clear

        assert_equal 4, twice.call
      end
    end
  end
end
