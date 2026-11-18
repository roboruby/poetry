# frozen_string_literal: true

require "json"
require "mcp"

module Poetry
  module Agent
    module MCP
      # Per-user authorization for the HTTP mount, the resource-server half
      # of MCP's authorization specification on the gem's own stack: the
      # protected resource metadata (RFC 9728) a host reads to find the
      # authorization server, the bearer challenge a request without a
      # token gets, and the verification of the token every request
      # carries. Poetry never issues tokens: the application (Doorkeeper,
      # say) or an identity provider is the authorization server, and the
      # verifier is how this server recognizes that server's tokens.
      #
      # A verified token is the request's identity: handlers built on the
      # gem read it as `server_context.auth_info`, and anything rendering
      # for the request (a document, a fragment, a tool) reads {.current}.
      #
      # The whole mount is protected by default. With `protected_tools:`
      # the mount is lazy: the handshake, the tool list and the other tools
      # answer without a token, and only a call of a protected tool is
      # challenged, so a host lets people use the open tools at once and
      # asks them to sign in when the conversation reaches one that needs
      # their account (Claude's lazy authentication, the spec's challenge
      # on the request that needs it).
      #
      # @example config/routes.rb
      #   auth = Poetry::Agent::MCP::Auth.new(
      #     resource: "https://shop.example/mcp", authorization_servers: ["https://shop.example"],
      #     scopes: ["mcp"],
      #     verifier: ->(token) do
      #       record = Doorkeeper::AccessToken.by_token(token)
      #       { subject: record.resource_owner_id.to_s, scopes: record.scopes.to_a,
      #         expires_at: record.expires_at&.to_i } if record&.accessible?
      #     end
      #   )
      #   mount auth.metadata_app => auth.well_known_path
      #   mount Poetry::Agent::MCP::HTTP.new(server, auth: auth) => "/mcp"
      class Auth
        # The Rack env key the gem's middleware stores the verified token under.
        ENV_KEY = ::MCP::Server::OAuth::ENV_KEY

        # Adapts a callable to the gem's verifier contract: the callable
        # takes the raw bearer token and answers an access token, a hash
        # of its parts (`subject:`, `scopes:`, `expires_at:`, `client_id:`,
        # `claims:`), or nil for a token it does not know. The hash is the
        # application's shape: a lookup in its own tables answers in one
        # line, and the audience check for a self-issued token is that
        # lookup, since the token exists only there.
        class Verifier
          # A verifier over a lookup.
          #
          # @param resource [String] the canonical resource the tokens are for
          # @param callable [#call] the lookup
          def initialize(resource, callable)
            @resource = resource
            @callable = callable
          end

          # The gem's contract.
          #
          # @param token [String] the raw bearer token
          # @return [::MCP::Server::OAuth::AccessToken]
          # @raise [::MCP::Server::OAuth::InvalidTokenError] for a token the lookup does not know
          def verify(token)
            case (found = @callable.call(token))
            when nil, false then raise ::MCP::Server::OAuth::InvalidTokenError
            when Hash then access_token(token, found)
            else found
            end
          end

          private

          # An access token from the hash's parts, under this resource.
          def access_token(token, parts)
            parts = parts.transform_keys(&:to_sym)
            ::MCP::Server::OAuth::AccessToken.new(
              token: token, client_id: parts[:client_id]&.to_s, scopes: Array(parts[:scopes]).map(&:to_s),
              expires_at: parts[:expires_at]&.to_i, subject: parts[:subject]&.to_s, issuer: parts[:issuer]&.to_s,
              audience: parts[:audience], resource: @resource, claims: parts[:claims] || {}
            )
          end
        end

        # The metadata document, the gem's.
        #
        # @return [::MCP::Server::OAuth::ProtectedResourceMetadata]
        attr_reader :metadata

        # The scopes every request needs.
        #
        # @return [Array<String>]
        attr_reader :required_scopes

        # The gem's verifier, or the adapted callable.
        #
        # @return [#verify]
        attr_reader :verifier

        # The verified token of the request being served, or nil outside
        # one (or on an open mount).
        #
        # @return [::MCP::Server::OAuth::AccessToken, nil]
        def self.current = Thread.current[:poetry_agent_mcp_auth]

        # Serves a block as the request the token authenticated.
        #
        # @param access_token [::MCP::Server::OAuth::AccessToken, nil]
        # @yield the block the identity applies to
        # @return [Object] the block's value
        def self.with(access_token)
          previous = Thread.current[:poetry_agent_mcp_auth]
          Thread.current[:poetry_agent_mcp_auth] = access_token
          yield
        ensure
          Thread.current[:poetry_agent_mcp_auth] = previous
        end

        # The authorization of one mount: its document, scopes and verifier.
        #
        # @param resource [String] the canonical URL of the MCP endpoint as hosts enter it
        #   (`https://shop.example/mcp`), the token's audience
        # @param authorization_servers [Array<String>] the issuer URLs; hosts read the first
        # @param scopes [Array<String>] the scopes the document advertises, the ones a host
        #   requests
        # @param verifier [#verify, #call, Hash] any object answering `verify(token)`, a callable
        #   (see {Verifier}), or a hash naming one of the gem's verifiers with its options:
        #   `{ jwt: { jwks_uri: } }` (an identity provider's signed tokens; needs the `jwt` gem)
        #   or `{ introspection: { introspection_endpoint:, client_id:, client_secret: } }`
        # @param required_scopes [Array<String>, nil] the scopes every request must carry;
        #   the advertised ones by default
        # @param resource_name [String, nil] a name for consent screens
        # @param documentation [String, nil] a URL for developers
        # @param protected_tools [Array<String, Symbol>, #call, nil] the tools that need the person's
        #   account, by name or as a callable `(name) -> Boolean`; nil protects the whole mount
        def initialize(resource:, authorization_servers:, verifier:, scopes: [], required_scopes: nil, # rubocop:disable Metrics/ParameterLists
                       resource_name: nil, documentation: nil, protected_tools: nil)
          @metadata = ::MCP::Server::OAuth::ProtectedResourceMetadata.new(
            resource: resource, authorization_servers: Array(authorization_servers),
            scopes_supported: (scopes.map(&:to_s) if scopes.any?),
            resource_name: resource_name, resource_documentation: documentation
          )
          @required_scopes = Array(required_scopes || scopes).map(&:to_s)
          @verifier = build_verifier(resource, verifier)
          @protected_tools = protected_tools
          return if protected_tools.nil? || protected_tools.respond_to?(:call)

          @protected_tools = Array(protected_tools).map(&:to_s)
        end

        # Whether only some tools need a token (the mount is lazy).
        #
        # @return [Boolean]
        def lazy? = !@protected_tools.nil?

        # Whether a tool needs the person's account on a lazy mount.
        #
        # @param name [String] the tool a call names
        # @return [Boolean] false on a mount protected as a whole, where the question never comes up
        def protected_tool?(name)
          return false unless lazy?
          return @protected_tools.call(name.to_s) ? true : false if @protected_tools.respond_to?(:call)

          @protected_tools.include?(name.to_s)
        end

        # The document's path at the origin's root, where hosts look for it
        # (`/.well-known/oauth-protected-resource/mcp` for a resource at `/mcp`).
        #
        # @return [String]
        def well_known_path = metadata.well_known_path

        # The document's absolute URL, the one the challenge names.
        #
        # @return [String]
        def well_known_url = metadata.well_known_url

        # A Rack app answering the document (GET and HEAD, with the CORS
        # headers a browser host needs, and OPTIONS), to mount at
        # {#well_known_path}.
        #
        # @return [#call]
        def metadata_app
          @metadata_app ||= MetadataApp.new(metadata)
        end

        # Wraps a Rack app in the gem's bearer enforcement: a request without
        # a token is challenged, one with a bad token refused, one with a
        # good token served with the token in the env and as {.current}. On
        # a lazy mount the gate is {Gate}: the challenge waits for a call of
        # a protected tool.
        #
        # @param app [#call] the app to protect
        # @return [#call]
        def protect(app)
          inner = ->(env) { self.class.with(env[ENV_KEY]) { app.call(env) } }
          return Gate.new(inner, self) if lazy?

          ::MCP::Server::OAuth::Middleware.new(inner, token_verifier: verifier, required_scopes: required_scopes,
                                                      resource_metadata: metadata)
        end

        private

        # The verifier from what the caller gave: the gem's by name with its
        # options (built on this document, so the audience and issuer are
        # the document's), an object with `verify`, or a callable adapted.
        def build_verifier(resource, verifier)
          return gem_verifier(verifier) if verifier.is_a?(Hash)
          return verifier if verifier.respond_to?(:verify)
          return Verifier.new(resource, verifier) if verifier.respond_to?(:call)

          raise ArgumentError, "verifier: needs verify(token), a callable, or a hash naming jwt: or introspection:"
        end

        # One of the gem's verifiers over this document, named by a one-key hash.
        def gem_verifier(named)
          kind, options = named.transform_keys(&:to_sym).first
          raise ArgumentError, "verifier: a hash names one verifier, jwt: or introspection:" unless options.is_a?(Hash)

          options = options.transform_keys(&:to_sym)
          case kind
          when :jwt then ::MCP::Server::OAuth::JWTVerifier.new(resource_metadata: metadata, **options)
          when :introspection
            ::MCP::Server::OAuth::IntrospectionVerifier.new(resource_metadata: metadata, **options)
          else raise ArgumentError, "verifier: unknown kind #{kind.inspect}, expected jwt: or introspection:"
          end
        end

        # The lazy mount's gate, decided on the request before the server
        # sees it: a request with a good token is served as that person;
        # one without, or with a bad or narrow one, is served as nobody
        # unless it calls a protected tool, when it gets the gem's challenge
        # (a 401 naming the document, a 403 `insufficient_scope` for a
        # narrow token) so the host signs the person in and retries the
        # call. A tool error inside a 200 would not: hosts start sign-in
        # on the transport's status alone.
        class Gate
          # The gate for one authorization over one app.
          #
          # @param app [#call] the app behind the gate
          # @param auth [Auth] the authorization
          def initialize(app, auth)
            @app = app
            @auth = auth
            @authenticator = ::MCP::Server::OAuth::Authenticator.new(token_verifier: auth.verifier,
                                                                     required_scopes: auth.required_scopes,
                                                                     resource_metadata: auth.metadata)
          end

          # The Rack entry point.
          #
          # @param env [Hash] the Rack environment
          # @return [Array(Integer, Hash, Array<String>)]
          def call(env)
            refusal = verify(env)
            return @app.call(env) if refusal.nil?
            return refusal if refusal.is_a?(Array)
            return @authenticator.challenge_response(refusal) if protected_call?(env)

            env.delete(ENV_KEY)
            @app.call(env)
          end

          private

          # Verifies the request's token into the env: nil on success, the
          # gem's error for a missing, bad or narrow token, or a 500 for a
          # verifier that failed (a JWKS or introspection endpoint down).
          def verify(env)
            env[ENV_KEY] = @authenticator.authenticate(env)
            nil
          rescue ::MCP::Server::OAuth::Error => e
            e
          rescue StandardError => e
            ::MCP.configuration.exception_reporter.call(e, { middleware: self.class.name })
            [500, { "content-type" => "application/json" }, [JSON.generate({ error: "server_error" })]]
          end

          # Whether the request calls a protected tool: a POST whose JSON
          # body (one message or a batch) carries a `tools/call` naming one.
          def protected_call?(env)
            return false unless env["REQUEST_METHOD"] == "POST" && (input = env["rack.input"])

            body = input.read.to_s
            input.rewind if input.respond_to?(:rewind)
            messages = JSON.parse(body)
            messages = [messages] unless messages.is_a?(Array)
            messages.any? do |message|
              next false unless message.is_a?(Hash) && message["method"] == "tools/call"

              @auth.protected_tool?(message.dig("params", "name").to_s)
            end
          rescue JSON::ParserError
            false
          end
        end

        # The metadata document as a Rack endpoint.
        class MetadataApp
          # The methods the document answers.
          METHODS = "GET, HEAD, OPTIONS"

          # The endpoint for one document, serialized once.
          #
          # @param metadata [::MCP::Server::OAuth::ProtectedResourceMetadata]
          def initialize(metadata)
            @json = metadata.to_json
          end

          # The Rack entry point.
          #
          # @param env [Hash] the Rack environment
          # @return [Array(Integer, Hash, Array<String>)]
          def call(env)
            case env["REQUEST_METHOD"]
            when "GET" then [200, headers, [@json]]
            when "HEAD" then [200, headers, []]
            when "OPTIONS"
              [204, { "access-control-allow-origin" => "*", "access-control-allow-methods" => METHODS,
                      "access-control-allow-headers" => "*" }, []]
            else
              [405, { "content-type" => "application/json", "allow" => METHODS },
               [JSON.generate({ "error" => "method_not_allowed" })]]
            end
          end

          private

          # The document's headers: JSON, cacheable, readable cross-origin.
          def headers
            { "content-type" => "application/json", "cache-control" => "public, max-age=3600",
              "access-control-allow-origin" => "*" }
          end
        end
      end
    end
  end
end
