# frozen_string_literal: true

require "json"
require "securerandom"
require "active_support"
require "active_support/message_verifier"
require_relative "host/csp"
require_relative "host/client"
require_relative "host/sandbox"
require_relative "host/rpc_app"

module Poetry
  module Agent
    module Apps
      # The host side of MCP Apps: other servers' apps inside a Rails page.
      # A host knows its servers (an id, a URL, the headers it holds for
      # them), reads their tools and app resources through its own client
      # (cached), calls tools for the page, answers an app's own requests
      # through an allowlist and the tool visibility the server declared,
      # and serves the sandbox proxy page the app runs in, on a second
      # origin by default, with the resource's policy as a header.
      #
      # The browser half is the `poetry--agent--mcp-app-host` controller:
      # it mounts the frame an app renders in, speaks the bridge, and sends
      # the app's requests to {RpcApp} (or a controller of the application's
      # own that calls {#rpc} with the signed-in user's headers).
      #
      # @example config/routes.rb
      #   host = Poetry::Agent::Apps::Host.new(
      #     servers: { "shop" => { url: "https://shop.example/mcp" } },
      #     origin: "https://chat.example", sandbox_origin: "https://apps.chat.example"
      #   )
      #   constraints(host: "apps.chat.example") { mount host.sandbox_app => host.sandbox_path }
      #   mount host.rpc_app => host.rpc_path
      class Host
        # An app's request the host will not make: a method outside the
        # allowlist, a tool the server hides from apps, a server it does
        # not know. Carries the JSON-RPC code the app is answered with.
        class Refused < StandardError
          # The JSON-RPC code the app is answered with.
          # @return [Integer]
          attr_reader :code

          # Names the refusal and the code it answers with.
          # @param message [String] what was refused and why
          # @param code [Integer] the JSON-RPC code (invalid params by default)
          def initialize(message, code: -32_602)
            super(message)
            @code = code
          end
        end

        # One server the host knows.
        #
        # @attr id [String] the id the page and the apps name it by
        # @attr url [String] the MCP endpoint
        # @attr headers [Hash] the headers the host holds for it
        Server = Struct.new(:id, :url, :headers, keyword_init: true)

        # An app resource as read: the HTML and its `_meta.ui`.
        #
        # @attr uri [String] the resource's `ui://` uri
        # @attr html [String] the app's document
        # @attr ui [Hash] the resource's `_meta.ui` (string keys), `{}` when none
        Resource = Struct.new(:uri, :html, :ui, keyword_init: true)

        # A tool call the page made, with everything the frame needs.
        #
        # @attr server [String] the server's id
        # @attr tool [String] the tool's name
        # @attr input [Hash] the arguments
        # @attr result [Hash] the `CallToolResult`
        # @attr resource_uri [String, nil] the app's resource, when the tool has one
        Call = Struct.new(:server, :tool, :input, :result, :resource_uri, keyword_init: true) do
          # Whether the tool has an app to show.
          # @return [Boolean]
          def app? = !resource_uri.nil?
        end

        # A small store with expiry, for a host without a Rails cache.
        class Store
          # An empty store.
          def initialize
            @entries = {}
            @mutex = Mutex.new
          end

          # The value under a key, computed and kept for `expires_in` seconds when absent or stale.
          #
          # @param key [String]
          # @param expires_in [Numeric]
          # @yieldreturn [Object] the value to keep
          # @return [Object]
          def fetch(key, expires_in:)
            @mutex.synchronize do
              entry = @entries[key]
              return entry[:value] if entry && entry[:until] > Process.clock_gettime(Process::CLOCK_MONOTONIC)
            end
            value = yield
            @mutex.synchronize { @entries[key] = { value: value, until: Process.clock_gettime(Process::CLOCK_MONOTONIC) + expires_in } }
            value
          end

          # Forgets everything.
          # @return [void]
          def clear = @mutex.synchronize { @entries.clear }
        end

        # The methods an app may send through the host.
        APP_METHODS = %w[tools/call resources/read ping notifications/message].freeze

        # How long a server's tool list is kept.
        TOOLS_TTL = 60

        # How long a resource is kept.
        RESOURCES_TTL = 600

        # How long a sandbox token stays valid, in seconds.
        TOKEN_TTL = 3600

        # The Stimulus controller the frame carries.
        CONTROLLER = "poetry--agent--mcp-app-host"

        # The host page's origin.
        # @return [String]
        attr_reader :origin

        # The apps origin, or nil for the inline mode.
        # @return [String, nil]
        attr_reader :sandbox_origin

        # Where the sandbox app is mounted.
        # @return [String]
        attr_reader :sandbox_path

        # Where the RPC app is mounted.
        # @return [String]
        attr_reader :rpc_path

        # The servers by id.
        # @return [Hash{String => Server}]
        attr_reader :servers

        # A host over its servers.
        #
        # @param servers [Hash{String => Hash}] by id: `url:` and optional `headers:`
        # @param origin [String] the host page's origin (`https://chat.example`)
        # @param sandbox_origin [String, nil] the apps origin serving the proxy page; nil runs the
        #   degraded inline mode (the proxy page as an opaque frame on the host page: no storage,
        #   no real origin for the app)
        # @param sandbox_path [String] where {#sandbox_app} is mounted on the apps origin
        # @param rpc_path [String] where {#rpc_app} (or the application's endpoint) answers
        # @param secret [String, nil] what signs the sandbox tokens; the application's secret key base by default
        # @param cache [#fetch, nil] a store answering `fetch(key, expires_in:) { }`; a {Store} by default
        # @param name [String] the client name servers see
        def initialize(servers:, origin:, sandbox_origin: nil, sandbox_path: "/mcp-apps/sandbox", # rubocop:disable Metrics/ParameterLists
                       rpc_path: "/mcp-apps/rpc", secret: nil, cache: nil, name: "poetry-agent")
          @servers = servers.to_h do |id, config|
            [id.to_s, Server.new(id: id.to_s, url: config.fetch(:url) do
              config.fetch("url")
            end, headers: (config[:headers] || config["headers"] || {}).to_h)]
          end
          @origin = origin.to_s.delete_suffix("/")
          @sandbox_origin = sandbox_origin&.to_s&.delete_suffix("/")
          @sandbox_path = sandbox_path
          @rpc_path = rpc_path
          @cache = cache || Store.new
          @name = name
          @verifier = ActiveSupport::MessageVerifier.new(secret || default_secret, serializer: JSON)
        end

        # A server by id.
        #
        # @param id [String]
        # @return [Server]
        # @raise [Refused] for an unknown id
        def server(id)
          @servers.fetch(id.to_s) { raise Refused, "unknown server: #{id}" }
        end

        # A connected client for a server.
        #
        # @param id [String]
        # @param headers [Hash] headers for this request (the signed-in user's, say) over the server's
        # @return [Client]
        def client(id, headers: {})
          held = server(id)
          Client.new(url: held.url, headers: held.headers.merge(headers.to_h), name: @name, post: @post).connect
        end

        # The server's tools with their app metadata, cached.
        #
        # @param id [String]
        # @param headers [Hash]
        # @return [Array<Hash>] `name:`, `description:`, `input_schema:`, `resource_uri:`, `visibility:`
        def tools(id, headers: {})
          @cache.fetch("poetry/apps/host/tools/#{id}", expires_in: TOOLS_TTL) do
            client(id, headers: headers).tools.map do |tool|
              ui = tool.dig("_meta", "ui") || tool.dig("_meta", :ui) || {}
              { name: tool["name"], description: tool["description"], input_schema: tool["inputSchema"],
                resource_uri: ui["resourceUri"] || ui[:resourceUri], visibility: ui["visibility"] || ui[:visibility] }
            end
          end
        end

        # Whether an app may call the tool: a visibility that names `app`, or none declared.
        #
        # @param id [String]
        # @param name [String]
        # @return [Boolean]
        def app_callable?(id, name)
          tool = tools(id).find { |held| held[:name] == name }
          !tool.nil? && (tool[:visibility].nil? || tool[:visibility].include?("app"))
        end

        # Whether the model (the page acting for it) may call the tool.
        #
        # @param id [String]
        # @param name [String]
        # @return [Boolean]
        def model_visible?(id, name)
          tool = tools(id).find { |held| held[:name] == name }
          !tool.nil? && (tool[:visibility].nil? || tool[:visibility].include?("model"))
        end

        # An app resource, cached.
        #
        # @param id [String]
        # @param uri [String]
        # @param headers [Hash]
        # @return [Resource]
        # @raise [Refused] for a resource that is not an app
        def resource(id, uri, headers: {})
          @cache.fetch("poetry/apps/host/resource/#{id}/#{uri}", expires_in: RESOURCES_TTL) do
            contents = client(id, headers: headers).read_resource(uri).first
            raise Refused.new("no resource at #{uri}", code: -32_002) unless contents

            mime = contents["mimeType"].to_s
            raise Refused, "not an app resource: #{mime}" unless mime == ::MCP::Apps::RESOURCE_MIME_TYPE

            html = contents["text"] || contents["blob"]&.unpack1("m")
            Resource.new(uri: uri, html: html.to_s, ui: (contents.dig("_meta", "ui") || {}).to_h)
          end
        end

        # A tool call made for the page (the model's side): the result and the app's resource uri.
        #
        # @param id [String]
        # @param name [String]
        # @param arguments [Hash]
        # @param headers [Hash]
        # @return [Call]
        # @raise [Refused] for a tool the model may not call
        def call(id, name, arguments = {}, headers: {})
          raise Refused, "not a model-visible tool: #{name}" unless model_visible?(id, name)

          tool = tools(id).find { |held| held[:name] == name }
          result = client(id, headers: headers).call_tool(name, arguments || {})
          Call.new(server: id.to_s, tool: name, input: arguments || {}, result: result,
                   resource_uri: tool[:resource_uri])
        end

        # An app's own request: through the allowlist and the visibility check.
        #
        # @param id [String]
        # @param method [String]
        # @param params [Hash]
        # @param headers [Hash]
        # @return [Hash, Array] the result
        # @raise [Refused] for a method outside the allowlist or a tool the app may not call
        def rpc(id, method, params = {}, headers: {})
          unless APP_METHODS.include?(method)
            raise Refused.new("not a method an app may send: #{method}",
                              code: -32_601)
          end

          params = (params || {}).to_h
          case method
          when "tools/call"
            name = params["name"].to_s
            raise Refused, "not a tool an app may call: #{name}" unless app_callable?(id, name)

            client(id, headers: headers).call_tool(name, params["arguments"] || {})
          when "resources/read" then { "contents" => client(id, headers: headers).read_resource(params["uri"].to_s) }
          when "ping" then {}
          when "notifications/message" then { "success" => true }
          end
        end

        # A signed claim on a resource for the sandbox page.
        #
        # @param id [String]
        # @param uri [String]
        # @return [String]
        def sandbox_token(id, uri)
          @verifier.generate({ "server" => id.to_s, "uri" => uri.to_s, "exp" => Time.now.to_i + TOKEN_TTL })
        end

        # The claim a token carries, or nil.
        #
        # @param token [String]
        # @return [Hash, nil] `"server"` and `"uri"`
        def verify_sandbox_token(token)
          claim = @verifier.verified(token.to_s)
          return nil unless claim.is_a?(Hash) && @servers.key?(claim["server"]) && claim["exp"].to_i > Time.now.to_i

          claim.slice("server", "uri")
        end

        # The sandbox page's URL for a resource, or nil in the inline mode.
        #
        # @param id [String]
        # @param uri [String]
        # @return [String, nil]
        def sandbox_url(id, uri)
          sandbox_origin && "#{sandbox_origin}#{sandbox_path}/#{sandbox_token(id, uri)}"
        end

        # The sandbox proxy page's app, to mount on the apps origin.
        #
        # @return [Sandbox]
        def sandbox_app
          @sandbox_app ||= Sandbox.new(self)
        end

        # The RPC endpoint, to mount on the host origin.
        #
        # @return [RpcApp]
        def rpc_app
          @rpc_app ||= RpcApp.new(self)
        end

        # The proxy page for the inline mode, with the resource's policy as a meta element.
        #
        # @param resource [Resource]
        # @return [String]
        def inline_sandbox_page(resource)
          sandbox_app.page(csp: Csp.header(resource.ui, frame_ancestors: nil))
        end

        # The frame element's data attributes: the controller and its values.
        #
        # @param call [Call] a call whose tool has an app
        # @param rpc_url [String, nil] where the app's requests go; {#rpc_path} by default
        # @return [Hash] for `tag.div(data: ...)`
        def frame_data(call, rpc_url: nil)
          data = { controller: CONTROLLER, "mcp-app-host" => "",
                   "#{CONTROLLER}-server-value" => call.server,
                   "#{CONTROLLER}-tool-value" => call.tool,
                   "#{CONTROLLER}-resource-value" => call.resource_uri,
                   "#{CONTROLLER}-input-value" => JSON.generate(call.input),
                   "#{CONTROLLER}-result-value" => JSON.generate(call.result),
                   "#{CONTROLLER}-rpc-url-value" => rpc_url || rpc_path }
          if (url = sandbox_url(call.server, call.resource_uri))
            data["#{CONTROLLER}-sandbox-url-value"] = url
            data["#{CONTROLLER}-sandbox-origin-value"] = sandbox_origin
          else
            data["#{CONTROLLER}-sandbox-page-value"] = inline_sandbox_page(resource(call.server, call.resource_uri))
          end
          data
        end

        # Forgets the cached tools and resources.
        # @return [void]
        def clear_cache
          @cache.clear if @cache.respond_to?(:clear)
        end

        # The transport seam for tests: a callable `(uri, body, headers) -> [status, headers, body]`.
        # @api private
        attr_writer :post

        private

        # The application's secret when there is one, else a secret for this process.
        def default_secret
          if defined?(Rails) && Rails.respond_to?(:application) && Rails.application.respond_to?(:secret_key_base)
            Rails.application.secret_key_base
          else
            SecureRandom.hex(32)
          end
        end
      end
    end
  end
end
