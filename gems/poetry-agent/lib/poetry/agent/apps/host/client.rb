# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require_relative "../../agui/sse"

module Poetry
  module Agent
    module Apps
      class Host
        # The host's MCP client: JSON-RPC over Streamable HTTP on the standard
        # library, enough for what a host does (initialize with the ui
        # extension, list tools, read a resource, call a tool, ping, log) and
        # nothing more. Answers come as JSON or as an event stream, with or
        # without a session; the raw results are kept, `_meta` included, which
        # is what a host reads tool visibility and a resource's policy from.
        #
        # @example
        #   client = Client.new(url: "https://shop.example/mcp", headers: { "Authorization" => "Bearer ..." })
        #   client.connect
        #   client.tools.first["_meta"]
        class Client
          # A JSON-RPC error the server answered, or a transport failure.
          class Error < StandardError
            # The JSON-RPC code, -32000 for a transport failure.
            # @return [Integer]
            attr_reader :code

            # The HTTP status the server answered, when the failure was one (a 401 wants fresh credentials).
            # @return [Integer, nil]
            attr_reader :http_status

            # Names the failure and its code.
            # @param message [String] the server's message, or the transport's
            # @param code [Integer] the JSON-RPC code
            # @param http_status [Integer, nil] the HTTP status, for a refused request
            def initialize(message, code: -32_000, http_status: nil)
              super(message)
              @code = code
              @http_status = http_status
            end
          end

          # The protocol version the client asks for.
          PROTOCOL_VERSION = "2025-06-18"

          # The server's declared capabilities, after {#connect}.
          #
          # @return [Hash, nil]
          attr_reader :server_capabilities

          # The server's name and version, after {#connect}.
          #
          # @return [Hash, nil]
          attr_reader :server_info

          # A client for one endpoint; nothing is sent until {#connect}.
          # @param url [String] the MCP endpoint
          # @param headers [Hash{String => String}] headers on every request (a bearer token, say)
          # @param name [String] this client's name for the handshake
          # @param version [String] this client's version
          # @param open_timeout [Numeric] seconds to connect
          # @param read_timeout [Numeric] seconds to wait for an answer
          # @param post [#call, nil] the transport, `(uri, body, headers) -> [status, headers, body]`;
          #   the standard library by default, a Rack app under test
          def initialize(url:, headers: {}, name: "poetry-agent", version: Poetry::Agent::VERSION, # rubocop:disable Metrics/ParameterLists
                         open_timeout: 5, read_timeout: 30, post: nil)
            @uri = URI.parse(url)
            @headers = headers.to_h.transform_keys(&:to_s)
            @name = name
            @version = version
            @open_timeout = open_timeout
            @read_timeout = read_timeout
            @post = post
            @session_id = nil
            @protocol_version = nil
            @next_id = 0
          end

          # The handshake: `initialize` with the ui extension declared, then
          # `notifications/initialized`. Idempotent.
          #
          # @return [self]
          def connect
            return self if @protocol_version

            result = request("initialize", {
                               "protocolVersion" => PROTOCOL_VERSION,
                               "capabilities" => { "extensions" => extensions },
                               "clientInfo" => { "name" => @name, "version" => @version }
                             })
            @protocol_version = result["protocolVersion"] || PROTOCOL_VERSION
            @server_capabilities = result["capabilities"]
            @server_info = result["serverInfo"]
            notify("notifications/initialized")
            self
          end

          # Whether the handshake happened.
          #
          # @return [Boolean]
          def connected? = !@protocol_version.nil?

          # The tools, raw, `_meta` included.
          #
          # @return [Array<Hash>]
          def tools
            Array(request("tools/list")["tools"])
          end

          # A resource's contents.
          #
          # @param uri [String]
          # @return [Array<Hash>] the contents items
          def read_resource(uri)
            Array(request("resources/read", { "uri" => uri })["contents"])
          end

          # A tool's result.
          #
          # @param name [String]
          # @param arguments [Hash]
          # @return [Hash] the `CallToolResult`
          def call_tool(name, arguments = {})
            request("tools/call", { "name" => name, "arguments" => arguments || {} })
          end

          # A ping.
          #
          # @return [Hash]
          def ping = request("ping")

          # A request by method, answered with its result.
          #
          # @param method [String]
          # @param params [Hash, nil]
          # @return [Hash] the result
          # @raise [Error] for a JSON-RPC error or a transport failure
          def request(method, params = nil)
            id = (@next_id += 1)
            message = { "jsonrpc" => "2.0", "id" => id, "method" => method }
            message["params"] = params if params
            answer = exchange(message)
            raise Error, "no answer to #{method}" unless answer

            if (error = answer["error"])
              raise Error.new(error["message"] || "error", code: error["code"] || -32_000)
            end

            answer["result"] || {}
          end

          # A notification, answered with nothing.
          #
          # @param method [String]
          # @param params [Hash, nil]
          # @return [void]
          def notify(method, params = nil)
            message = { "jsonrpc" => "2.0", "method" => method }
            message["params"] = params if params
            exchange(message, expect: false)
            nil
          end

          private

          # The ui extension, declared as the handshake carries it.
          def extensions
            Apps.capabilities.to_h[:extensions].transform_keys(&:to_s)
          end

          # Posts a message and reads the answer with its id from a JSON body or
          # an event stream; keeps the session the server assigns.
          def exchange(message, expect: true)
            status, headers, body = post(JSON.generate(message))
            headers = headers.to_h.transform_keys { |key| key.to_s.downcase }
            @session_id = headers["mcp-session-id"] if headers["mcp-session-id"]
            unless (200..299).cover?(status.to_i)
              raise Error.new("#{@uri} answered #{status}",
                              http_status: status.to_i)
            end
            return nil unless expect

            type = headers["content-type"].to_s
            answers = type.include?("text/event-stream") ? events(body) : [JSON.parse(body)].flatten
            answers.grep(Hash).find { |held| held["id"] == message["id"] }
          rescue JSON::ParserError => e
            raise Error, "#{@uri} answered something other than JSON: #{e.message[0, 80]}"
          end

          # The messages in an event stream.
          def events(body)
            parser = AGUI::SSE::Parser.new
            found = []
            parser.feed(body.to_s) { |event| found << event }
            parser.finish { |event| found << event }
            found
          end

          # The transport: the standard library, or the seam a test provides.
          def post(body)
            headers = { "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream" }
            headers["Mcp-Session-Id"] = @session_id if @session_id
            headers["MCP-Protocol-Version"] = @protocol_version if @protocol_version
            headers.merge!(@headers)
            return @post.call(@uri, body, headers) if @post

            request = Net::HTTP::Post.new(@uri)
            headers.each { |name, value| request[name] = value }
            request.body = body
            options = { use_ssl: @uri.scheme == "https", open_timeout: @open_timeout, read_timeout: @read_timeout }
            response = Net::HTTP.start(@uri.host, @uri.port, **options) { |http| http.request(request) }
            [response.code.to_i, response.each_header.to_h, response.body.to_s]
          rescue SystemCallError, Timeout::Error, IOError, SocketError, OpenSSL::SSL::SSLError => e
            raise Error, "#{@uri} unreachable: #{e.class}"
          end
        end
      end
    end
  end
end
