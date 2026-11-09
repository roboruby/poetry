# frozen_string_literal: true

require "mcp/client/oauth"

module Poetry
  module Agent
    module Apps
      class Host
        # A server's credentials from the `mcp` gem's own OAuth client: a
        # person's tokens toward the server, obtained by the authorization
        # code flow with PKCE (discovery of the server's authorization
        # server, a client ID metadata document or dynamic registration, the
        # token exchange, refresh), kept in a storage the application
        # supplies per person and server. {#headers} answers the bearer
        # token, or raises {AuthorizationRequired} with the URL to send the
        # person to; the application's callback action finishes with
        # {#finish}. One callback path per server: the redirect URI given
        # gains the server's id as its last segment, so the callback knows
        # which server's storage holds the pending authorization.
        class OAuth
          # What a client is unless the metadata says otherwise: a public
          # client on the authorization code grant that may refresh.
          DEFAULT_CLIENT_METADATA = {
            client_name: "poetry-agent",
            grant_types: %w[authorization_code refresh_token],
            response_types: %w[code],
            token_endpoint_auth_method: "none"
          }.freeze

          # The callback URL's base; the server's id is appended.
          # @return [String]
          attr_reader :redirect_uri

          # The client's metadata, without the redirect URIs (filled per server).
          # @return [Hash{Symbol => Object}]
          attr_reader :client_metadata

          # The gem's client for a host's servers.
          #
          # @param redirect_uri [String] the callback URL's base (`https://chat.example/mcp-apps/callback`);
          #   the server's id is appended, so the application routes `callback/:server`
          # @param storage [#call, Object] `(context, server) -> storage`: a storage answering the gem's
          #   interface (`tokens`, `save_tokens`, `client_information`, `save_client_information`,
          #   `save_pending_authorization`, `pending_authorization`, `delete_pending_authorization`) for
          #   that person and server; an object answering it serves everyone
          # @param client_metadata [Hash] the client's registration metadata (`client_name`, `grant_types`,
          #   `response_types`, `token_endpoint_auth_method`, `client_uri`, ...); `redirect_uris` is filled
          #   per server
          # @param scope [String, nil] the scope to ask for; what the server advertises by default
          # @param client_id_metadata_document_url [String, nil] the client's hosted metadata document, used
          #   in place of dynamic registration where the authorization server supports it
          # @param http_client_customizer [#call, nil] a hook on the gem's HTTP connection (middleware, an
          #   adapter under test)
          # @param pending_authorization_max_age [Integer] seconds a started authorization stays redeemable
          def initialize(redirect_uri:, storage:, client_metadata: {}, scope: nil, # rubocop:disable Metrics/ParameterLists
                         client_id_metadata_document_url: nil, http_client_customizer: nil,
                         pending_authorization_max_age: 600)
            @client_metadata = DEFAULT_CLIENT_METADATA.merge(client_metadata.to_h.transform_keys(&:to_sym))
            @client_metadata.delete(:redirect_uris)
            @redirect_uri = redirect_uri.to_s.delete_suffix("/")
            @storage = storage
            @scope = scope
            @client_id_metadata_document_url = client_id_metadata_document_url
            @http_client_customizer = http_client_customizer
            @pending_authorization_max_age = pending_authorization_max_age
          end

          # The bearer header for a person toward a server.
          #
          # @param context [Object] the person (whatever the storage is keyed by)
          # @param server [Server] the server the token is for
          # @return [Hash{String => String}] the Authorization header
          # @raise [AuthorizationRequired] when there is no token yet; its URL starts the flow
          def headers(context, server)
            token = provider(context, server).access_token
            raise AuthorizationRequired.new(server: server.id, url: authorization_url(context, server)) unless token

            { "Authorization" => "Bearer #{token}" }
          end

          # Trades the refresh token for a new access token.
          #
          # @param context [Object] the person
          # @param server [Server] the server the token is for
          # @return [Boolean] whether there is a new token
          def refresh(context, server)
            flow(context, server).refresh!(server_url: server.url) == :refreshed
          rescue ::MCP::Client::OAuth::Flow::AuthorizationError
            false
          end

          # Starts an authorization: discovery, registration, a pending
          # authorization saved in the storage; the URL to send the person to.
          #
          # @param context [Object] the person
          # @param server [Server] the server the token is for
          # @return [String] the authorization URL
          def authorization_url(context, server)
            flow = flow(context, server)
            flow.run!(server_url: server.url)
            flow.authorization_url.to_s
          end

          # Finishes an authorization with the callback's query (`code`, `state`, `iss`).
          #
          # @param context [Object] the person
          # @param server [Server] the server the token is for
          # @param params [Hash] the callback's query parameters, as they arrived
          # @return [Boolean] whether tokens were saved
          # @raise [MCP::Client::OAuth::Flow::AuthorizationError] for a callback that does not match a pending
          #   authorization, an error the authorization server sent, or a refused exchange
          def finish(context, server, params) # rubocop:disable Naming/PredicateMethod -- an action with an outcome, not a question
            flow(context, server).finish!(server_url: server.url, callback_params: params.to_h) == :authorized
          end

          # Whether the person has a token toward the server.
          #
          # @param context [Object] the person
          # @param server [Server] the server the token is for
          # @return [Boolean]
          def authorized?(context, server)
            !provider(context, server).access_token.nil?
          end

          # The callback URL for a server.
          #
          # @param server [Server] the server the token is for
          # @return [String]
          def redirect_uri_for(server)
            "#{@redirect_uri}/#{server.id}"
          end

          private

          # The gem's provider for one person and server.
          def provider(context, server)
            uri = redirect_uri_for(server)
            ::MCP::Client::OAuth::Provider.new(
              client_metadata: @client_metadata.merge(redirect_uris: [uri]), redirect_uri: uri,
              redirect_handler: ->(_url) {}, scope: @scope, storage: storage_for(context, server),
              client_id_metadata_document_url: @client_id_metadata_document_url,
              http_client_customizer: @http_client_customizer,
              pending_authorization_max_age: @pending_authorization_max_age
            )
          end

          # The gem's flow over that provider.
          def flow(context, server)
            ::MCP::Client::OAuth::Flow.new(provider: provider(context, server))
          end

          # The storage for one person and server.
          def storage_for(context, server)
            @storage.respond_to?(:call) ? @storage.call(context, server) : @storage
          end
        end
      end
    end
  end
end
