# frozen_string_literal: true

require "json"

module Poetry
  module Agent
    module MCP
      # The MCP server over HTTP: a Rack app answering JSON-RPC 2.0 POSTs
      # (the Streamable HTTP transport's request/response half) with the
      # same pure {Server#handle} the stdio exe uses - one surface, two
      # transports. Mount it at the conventional same-origin `/mcp`, which
      # is where in-page bridges (Cloudflare's WebMCP Site MCP Server pack
      # among them) look for a site's own MCP server.
      #
      # Read-only by construction (every tool describes or verifies), so
      # exposing it is a discovery surface, not a mutation surface. The
      # Origin header is validated against the request's own host, so a
      # cross-site page cannot drive it through a visitor's browser.
      #
      # @example config/routes.rb
      #   mount Poetry::Agent::MCP::HTTP.new => "/mcp"
      class HTTP
        # The response media type.
        JSON_TYPE = "application/json"

        # @param server [Server, Proc, nil] the server, a lambda building it
        #   on first request, or nil for the bundled assembly
        def initialize(server = nil)
          @server = server
        end

        # The Rack entry point.
        #
        # @param env [Hash] the Rack environment
        # @return [Array(Integer, Hash, Array<String>)] status, headers, body
        def call(env)
          request = Rack::Request.new(env)
          return not_allowed unless request.post?
          return forbidden unless same_origin?(request)

          payload = JSON.parse(request.body.read)
          # A batch is an Array; a single request is a Hash (never Array() a
          # Hash - it splits into pairs).
          messages = payload.is_a?(Array) ? payload : [payload]
          responses = messages.filter_map { |message| server.handle(message) }
          return [202, headers, []] if responses.empty?

          body = payload.is_a?(Array) ? responses : responses.first
          [200, headers, [JSON.generate(body)]]
        rescue JSON::ParserError => e
          [400, headers, [JSON.generate(rpc_error(-32_700, "parse error: #{e.message}"))]]
        end

        private

        def server
          @server = @server.call if @server.respond_to?(:call) && !@server.respond_to?(:handle)
          @server ||= Bundled.server
        end

        def headers
          { "content-type" => JSON_TYPE, "cache-control" => "no-store" }
        end

        def not_allowed
          [405, headers.merge("allow" => "POST"),
           [JSON.generate(rpc_error(-32_601, "POST JSON-RPC only (SSE streaming is not offered)"))]]
        end

        def forbidden
          [403, headers, [JSON.generate(rpc_error(-32_600, "origin not allowed"))]]
        end

        # An absent Origin (same-origin fetch, curl, an MCP client) passes;
        # a present one must match the request's own scheme + host.
        def same_origin?(request)
          origin = request.get_header("HTTP_ORIGIN")
          return true if origin.nil? || origin.empty?

          origin.casecmp?("#{request.scheme}://#{request.host_with_port}")
        end

        def rpc_error(code, message)
          { "jsonrpc" => "2.0", "id" => nil, "error" => { "code" => code, "message" => message } }
        end
      end
    end
  end
end
