# frozen_string_literal: true

require "test_helper"
require "action_controller"
require "rack/mock"
require "json"
require "faraday"

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
          return [401, { "content-type" => "application/json" }, ""] if @reject && headers["Authorization"] == @reject

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
        csp = { "connectDomains" => ["https://api.example"] }
        with_policy = subject.sandbox_token("shop", "ui://shop/plans", csp: csp)

        assert_equal csp, subject.verify_sandbox_token(with_policy)["csp"]
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

      # --- credentials: a callable, the gem's OAuth client, the endpoint's context ---

      def test_a_server_s_credentials_turn_the_context_into_headers_for_every_request
        seen = []
        credentials = lambda do |context, held|
          seen << [context, held.id]
          { "Authorization" => "Bearer #{context}-token" }
        end
        subject = Apps::Host.new(servers: { "shop" => { url: "https://shop.example/mcp", headers: { "X-Shop" => "yes" },
                                                        credentials: credentials } },
                                 origin: ORIGIN, sandbox_origin: APPS, secret: "s3cret").tap { |held| held.post = post }

        call = subject.call("shop", "show_plans", { "team_size" => 2 }, context: "alice")

        assert_equal "plans for 2", call.result.dig("content", 0, "text")
        assert_equal "Bearer alice-token", @posts.last[:headers]["Authorization"]
        assert_equal "yes", @posts.last[:headers]["X-Shop"], "the server's own headers stay"
        assert_includes seen, %w[alice shop]
        assert subject.authorized?("shop", context: "alice"), "a callable holds no authorization of its own"
        assert_raises(ArgumentError) { subject.authorization_url("shop", context: "alice") }
      end

      def test_the_oauth_client_sends_the_person_to_authorize_then_sends_their_token_and_refreshes_it
        stubs = Faraday::Adapter::Test::Stubs.new
        json = ->(status, body) { [status, { "Content-Type" => "application/json" }, JSON.generate(body)] }
        stubs.get("https://shop.example/.well-known/oauth-protected-resource/mcp") do
          json.call(200, "resource" => "https://shop.example/mcp", "authorization_servers" => ["https://auth.example"],
                         "scopes_supported" => ["plans"])
        end
        stubs.get("https://auth.example/.well-known/oauth-authorization-server") do
          json.call(200, "issuer" => "https://auth.example",
                         "authorization_endpoint" => "https://auth.example/authorize",
                         "token_endpoint" => "https://auth.example/token",
                         "registration_endpoint" => "https://auth.example/register",
                         "response_types_supported" => ["code"],
                         "grant_types_supported" => %w[authorization_code refresh_token],
                         "code_challenge_methods_supported" => ["S256"],
                         "token_endpoint_auth_methods_supported" => ["none"],
                         "scopes_supported" => ["plans"])
        end
        stubs.post("https://auth.example/register") do
          json.call(201, "client_id" => "client-1", "redirect_uris" => ["https://chat.example/mcp-apps/callback/shop"],
                         "token_endpoint_auth_method" => "none", "grant_types" => %w[authorization_code refresh_token],
                         "response_types" => ["code"])
        end
        exchanges = []
        stubs.post("https://auth.example/token") do |env|
          form = env.body.is_a?(String) ? URI.decode_www_form(env.body).to_h : env.body.to_h.transform_keys(&:to_s)
          exchanges << form
          token = form["grant_type"] == "refresh_token" ? "t2" : "t1"
          json.call(200, "access_token" => token, "token_type" => "Bearer", "expires_in" => 3600,
                         "refresh_token" => "r1")
        end
        stores = Hash.new { |held, key| held[key] = ::MCP::Client::OAuth::InMemoryStorage.new }
        oauth = Apps::Host::OAuth.new(redirect_uri: "https://chat.example/mcp-apps/callback/",
                                      storage: ->(context, held) { stores[[context, held.id]] },
                                      http_client_customizer: ->(faraday) { faraday.adapter(:test, stubs) })
        subject = Apps::Host.new(servers: { "shop" => { url: "https://shop.example/mcp", credentials: oauth } },
                                 origin: ORIGIN, sandbox_origin: APPS, secret: "s3cret").tap { |held| held.post = post }

        refute subject.authorized?("shop", context: "alice")
        error = assert_raises(Apps::Host::AuthorizationRequired) { subject.tools("shop", context: "alice") }
        assert_equal "shop", error.server
        assert_equal(-32_001, error.code)
        url = URI.parse(error.url)
        query = URI.decode_www_form(url.query.to_s).to_h

        assert_equal "https://auth.example/authorize", "#{url.scheme}://#{url.host}#{url.path}"
        assert_equal "S256", query["code_challenge_method"]
        assert_equal "https://shop.example/mcp", query["resource"]
        assert_equal "https://chat.example/mcp-apps/callback/shop", query["redirect_uri"]
        assert_equal "client-1", query["client_id"]
        assert_empty @posts, "nothing reached the server before the person authorized"

        assert subject.finish_authorization("shop", context: "alice",
                                                    params: { "code" => "abc", "state" => query["state"] })
        assert subject.authorized?("shop", context: "alice")
        assert_equal "abc", exchanges.last["code"]
        assert_equal "authorization_code", exchanges.last["grant_type"]
        refute subject.authorized?("shop", context: "bob"), "tokens are the person's"

        subject.tools("shop", context: "alice")

        assert_equal "Bearer t1", @posts.last[:headers]["Authorization"]

        @reject = "Bearer t1"
        call = subject.call("shop", "show_plans", { "team_size" => 3 }, context: "alice")

        assert_equal "plans for 3", call.result.dig("content", 0, "text")
        assert_equal "refresh_token", exchanges.last["grant_type"]
        assert_equal "Bearer t2", @posts.last[:headers]["Authorization"],
                     "a 401 is tried once more with the refreshed token"
      end

      def test_the_rpc_endpoint_reads_the_context_from_the_environment_and_answers_an_authorization_as_unauthorized
        credentials = lambda do |context, held|
          if context == "bob"
            raise Apps::Host::AuthorizationRequired.new(server: held.id,
                                                        url: "https://auth.example/start")
          end

          { "Authorization" => "Bearer #{context}-token" }
        end
        subject = Apps::Host.new(servers: { "shop" => { url: "https://shop.example/mcp", credentials: credentials } },
                                 origin: ORIGIN, sandbox_origin: APPS, secret: "s3cret").tap { |held| held.post = post }
        app = Apps::Host::RpcApp.new(subject, context: ->(env) { env["HTTP_X_USER"] })
        body = JSON.generate("server" => "shop", "method" => "tools/call", "params" => { "name" => "choose_plan" })
        request = lambda do |user|
          Rack::MockRequest.new(app).post("/mcp-apps/rpc", "CONTENT_TYPE" => "application/json",
                                                           "HTTP_SEC_FETCH_SITE" => "same-origin",
                                                           "HTTP_X_USER" => user, input: body)
        end

        response = request.call("alice")

        assert_equal 200, response.status
        assert_equal "Bearer alice-token", @posts.last[:headers]["Authorization"]

        response = request.call("bob")
        error = JSON.parse(response.body)["error"]

        assert_equal 401, response.status
        assert_equal(-32_001, error["code"])
        assert_equal "https://auth.example/start", error.dig("data", "authorizationUrl")
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
