# frozen_string_literal: true

require "test_helper"
require "rack/test"
require "openssl"
require "jwt"

module Poetry
  module Agent
    # Per-user authorization on the HTTP mount: the protected resource
    # metadata hosts read, the challenge a request without a token gets,
    # the refusal of a bad one, and the verified token as the request's
    # identity, through a lookup of the application's own and through
    # the gem's JWT verifier.
    class MCPAuthTest < Minitest::Test
      include Rack::Test::Methods

      RESOURCE = "https://shop.example/mcp"
      ISSUER = "https://shop.example"
      TOKENS = { "alice-token" => { subject: "alice", scopes: %w[mcp], expires_at: Time.now.to_i + 600 },
                 "narrow-token" => { subject: "bob", scopes: %w[other] } }.freeze
      INITIALIZE = { "protocolVersion" => MCP::PROTOCOL_VERSION, "capabilities" => {},
                     "clientInfo" => { "name" => "test", "version" => "0" } }.freeze

      def auth(**)
        MCP::Auth.new(resource: RESOURCE, authorization_servers: [ISSUER], scopes: %w[mcp],
                      verifier: ->(token) { TOKENS[token] }, **)
      end

      # The mount under test: the bundled server plus a tool that answers
      # with the request's identity, both ways the identity travels.
      def app
        @app ||= begin
          server = MCP::Bundled.server(app_root: Dir.pwd)
          server.mcp.define_tool(name: "whoami", description: "The caller",
                                 input_schema: { type: "object" }) do |server_context:, **|
            ::MCP::Tool::Response.new([{ type: "text",
                                         text: "#{MCP::Auth.current&.subject}/#{server_context.auth_info&.subject}" }])
          end
          MCP::HTTP.new(server, auth: auth)
        end
      end

      def rpc(method, params = {}, token: nil, origin: nil)
        headers = { "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json" }
        headers["HTTP_AUTHORIZATION"] = "Bearer #{token}" if token
        headers["HTTP_ORIGIN"] = origin if origin
        post "/", JSON.generate({ "jsonrpc" => "2.0", "id" => 1, "method" => method, "params" => params }), headers
        last_response.body.empty? ? nil : JSON.parse(last_response.body)
      end

      # --- the document ---

      def test_the_metadata_names_the_resource_its_servers_and_scopes_at_the_well_known_path
        subject = auth(resource_name: "Shop", documentation: "https://shop.example/docs")

        assert_equal "/.well-known/oauth-protected-resource/mcp", subject.well_known_path
        assert_equal "https://shop.example/.well-known/oauth-protected-resource/mcp", subject.well_known_url
        document = JSON.parse(subject.metadata.to_json)

        assert_equal RESOURCE, document["resource"]
        assert_equal [ISSUER], document["authorization_servers"]
        assert_equal %w[mcp], document["scopes_supported"]
        assert_equal ["header"], document["bearer_methods_supported"]
        assert_equal "Shop", document["resource_name"]
        assert_equal %w[mcp], subject.required_scopes
        assert_equal %w[read], auth(required_scopes: %w[read]).required_scopes
        assert_raises(ArgumentError) { auth(resource: "http://shop.example/mcp") }
      end

      def test_the_metadata_app_answers_the_document_with_cors_and_refuses_other_methods
        endpoint = Rack::MockRequest.new(auth.metadata_app)
        response = endpoint.get("/")

        assert_equal 200, response.status
        assert_equal "application/json", response.headers["content-type"]
        assert_equal "*", response.headers["access-control-allow-origin"]
        assert_equal RESOURCE, JSON.parse(response.body)["resource"]
        assert_equal 200, endpoint.head("/").status
        assert_empty endpoint.head("/").body
        assert_equal 204, endpoint.options("/").status
        assert_equal 405, endpoint.post("/").status
      end

      # --- the verifier ---

      def test_a_callable_verifier_answers_a_hash_a_token_or_nothing
        verifier = auth.verifier
        token = verifier.verify("alice-token")

        assert_kind_of ::MCP::Server::OAuth::AccessToken, token
        assert_equal "alice", token.subject
        assert_equal %w[mcp], token.scopes
        assert_equal RESOURCE, token.resource
        assert_raises(::MCP::Server::OAuth::InvalidTokenError) { verifier.verify("unknown") }
        ready = ::MCP::Server::OAuth::AccessToken.new(token: "x", subject: "carol")

        assert_same ready, MCP::Auth::Verifier.new(RESOURCE, ->(_) { ready }).verify("x")
        own = Object.new.tap { |o| o.define_singleton_method(:verify) { |_| ready } }

        assert_same own, auth(verifier: own).verifier
        assert_raises(ArgumentError) { auth(verifier: "nope") }
        assert_raises(ArgumentError) { auth(verifier: { nope: {} }) }
        assert_raises(ArgumentError) { auth(verifier: { jwt: nil }) }
      end

      # --- the mount ---

      def test_a_request_without_a_token_is_challenged_with_the_document_s_address
        reply = rpc("tools/list")

        assert_equal 401, last_response.status
        assert_nil reply
        challenge = last_response.headers["www-authenticate"]

        assert_match(/\ABearer /, challenge)
        assert_includes challenge, %(scope="mcp")
        assert_includes challenge, %(resource_metadata="https://shop.example/.well-known/oauth-protected-resource/mcp")
      end

      def test_a_bad_token_is_refused_and_a_narrow_one_asked_to_step_up
        reply = rpc("tools/list", token: "forged")

        assert_equal 401, last_response.status
        assert_equal "invalid_token", reply["error"]
        assert_includes last_response.headers["www-authenticate"], %(error="invalid_token")
        reply = rpc("tools/list", token: "narrow-token")

        assert_equal 403, last_response.status
        assert_equal "insufficient_scope", reply["error"]
        assert_includes last_response.headers["www-authenticate"], %(scope="mcp")
      end

      def test_a_good_token_is_served_and_is_the_request_s_identity
        reply = rpc("initialize", INITIALIZE, token: "alice-token")

        assert_predicate last_response, :ok?
        assert_equal "poetry-agent", reply.dig("result", "serverInfo", "name")
        text = rpc("tools/call", { "name" => "whoami", "arguments" => {} }, token: "alice-token")
               .dig("result", "content", 0, "text")

        assert_equal "alice/alice", text, "the identity reaches Poetry's current and the gem's server context"
        assert_nil MCP::Auth.current, "the identity does not outlive the request"
      end

      def test_the_origin_check_comes_first_and_a_failing_verifier_is_an_internal_error
        rpc("tools/list", token: "alice-token", origin: "https://evil.example")

        assert_equal 403, last_response.status
        assert_equal "origin not allowed", JSON.parse(last_response.body).dig("error", "message")
        broken = MCP::HTTP.new(MCP::Bundled.server(app_root: Dir.pwd),
                               auth: auth(verifier: ->(_) { raise IOError, "introspection down" }))
        body = JSON.generate({ "jsonrpc" => "2.0", "id" => 1, "method" => "tools/list" })
        response = Rack::MockRequest.new(broken).post("/", "CONTENT_TYPE" => "application/json",
                                                           "HTTP_ACCEPT" => "application/json",
                                                           "HTTP_AUTHORIZATION" => "Bearer any", input: body)

        assert_equal 500, response.status
        assert_equal "server_error", JSON.parse(response.body)["error"]
      end

      def test_the_gem_s_jwt_verifier_takes_an_identity_provider_s_signed_tokens
        key = OpenSSL::PKey::RSA.new(2048)
        subject = auth(verifier: { jwt: { key: key.public_key } })
        signed = lambda do |claims|
          JWT.encode({ "iss" => ISSUER, "aud" => RESOURCE, "sub" => "dana", "scope" => "mcp",
                       "exp" => Time.now.to_i + 300 }.merge(claims), key, "RS256")
        end

        assert_equal "dana", subject.verifier.verify(signed.call({})).subject
        assert_raises(::MCP::Server::OAuth::InvalidTokenError) { subject.verifier.verify(signed.call("aud" => "https://other.example")) }
        assert_raises(::MCP::Server::OAuth::InvalidTokenError) { subject.verifier.verify(signed.call("exp" => Time.now.to_i - 1)) }
        assert_raises(ArgumentError) { auth(verifier: { introspection: { introspection_endpoint: "http://as.example/introspect" } }) }
      end
    end
  end
end
