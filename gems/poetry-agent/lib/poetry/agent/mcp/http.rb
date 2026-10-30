# frozen_string_literal: true

require "json"
require "mcp"

module Poetry
  module Agent
    module MCP
      # The MCP server over HTTP: the gem's Streamable HTTP transport, as a
      # Rack app, in its stateless JSON mode (one POST, one JSON reply; no
      # session to keep, no event stream to hold), over the same server the
      # stdio exe serves - one surface, two transports. Mount it at the
      # conventional same-origin `/mcp`, which is where in-page bridges
      # (WebMCP site MCP server packs among them) look for a site's own MCP
      # server; a browser client sends `Accept: application/json`.
      #
      # Read-only by construction (every tool describes or verifies), so
      # exposing it is a discovery surface, not a mutation surface. The
      # Origin header is validated against the request's own host, so a
      # cross-site page cannot drive it through a visitor's browser;
      # `allowed_origins:` names the other origins to let in. The Host
      # header is the host application's to validate (Rails does), so the
      # transport's own loopback-only host check stays off.
      #
      # @example config/routes.rb
      #   mount Poetry::Agent::MCP::HTTP.new => "/mcp"
      class HTTP
        # A Rack endpoint over a server, a callable that builds one, or the bundled default.
        # @param server [Server, Proc, nil] the server, a lambda building it
        #   on first request, or nil for the bundled assembly
        # @param allowed_origins [Array<String>, nil] origins accepted beside the request's own
        def initialize(server = nil, allowed_origins: nil)
          @server = server
          @allowed_origins = allowed_origins
        end

        # The Rack entry point.
        #
        # @param env [Hash] the Rack environment
        # @return [Array(Integer, Hash, Array<String>)] status, headers, body
        def call(env)
          request = Rack::Request.new(env)
          return forbidden unless origin_allowed?(request)

          Apps.with_request_origin(request.base_url) { transport.call(env) }
        end

        private

        # An absent Origin (same-origin fetch, curl, an MCP client) passes;
        # a present one must match the request's own scheme + host, or be
        # allow-listed.
        def origin_allowed?(request)
          origin = request.get_header("HTTP_ORIGIN")
          return true if origin.nil? || origin.empty?
          return true if Array(@allowed_origins).any? { |allowed| origin.casecmp?(allowed) }

          origin.casecmp?("#{request.scheme}://#{request.host_with_port}")
        end

        # The 403 response for a cross-origin request.
        def forbidden
          error = { "code" => -32_600, "message" => "origin not allowed" }
          [403, { "content-type" => "application/json" },
           [JSON.generate({ "jsonrpc" => "2.0", "id" => nil, "error" => error })]]
        end

        # The MCP server, built on first use.
        def server
          @server = @server.call if @server.respond_to?(:call) && !@server.respond_to?(:handle)
          @server ||= Bundled.server
        end

        # The gem's transport over the server, built on first use.
        def transport
          @transport ||= ::MCP::Server::Transports::StreamableHTTPTransport.new(
            server.mcp, stateless: true, enable_json_response: true, dns_rebinding_protection: false
          )
        end
      end
    end
  end
end
