# frozen_string_literal: true

require "json"

module Poetry
  module Agent
    module Apps
      class Host
        # The Rack endpoint an app's own requests go through: `POST` a JSON
        # body `{ "server", "method", "params" }` and get `{ "result" }` or
        # `{ "error": { "code", "message" } }`. Same-origin only (the
        # browser's fetch metadata, else the Origin header), since a bare
        # Rack app sees no CSRF token. The signed-in person reaches the
        # servers' credentials through `context:`, a callable reading the
        # Rack environment (Warden's user, say); an application that would
        # rather do it in a controller calls {Host#rpc} from one of its own.
        # A server that wants the person authorized first is answered with
        # a 401 carrying the URL that starts it.
        class RpcApp
          # The endpoint for one host.
          # @param host [Host] the host whose servers it relays to
          # @param context [#call, nil] `(env) -> context`, what the servers' credentials are keyed by
          def initialize(host, context: nil)
            @host = host
            @context = context
          end

          # The Rack entry point.
          #
          # @param env [Hash] the Rack environment
          # @return [Array(Integer, Hash, Array<String>)]
          def call(env)
            unless env["REQUEST_METHOD"] == "POST"
              return answer(405,
                            { "error" => { "code" => -32_600,
                                           "message" => "POST only" } })
            end
            unless same_origin?(env)
              return answer(403,
                            { "error" => { "code" => -32_600,
                                           "message" => "same-origin only" } })
            end

            body = JSON.parse(env["rack.input"].read.to_s)
            result = @host.rpc(body.fetch("server").to_s, body.fetch("method").to_s, body["params"] || {},
                               context: @context&.call(env))
            answer(200, { "result" => result })
          rescue JSON::ParserError, KeyError
            answer(400,
                   { "error" => { "code" => -32_700, "message" => "a JSON object with server, method and params" } })
          rescue Refused => e
            answer(403, { "error" => { "code" => e.code, "message" => e.message } })
          rescue AuthorizationRequired => e
            answer(401,
                   { "error" => { "code" => e.code, "message" => e.message,
                                  "data" => { "authorizationUrl" => e.url } } })
          rescue Client::Error => e
            answer(502, { "error" => { "code" => e.code, "message" => e.message } })
          end

          private

          # Whether the request comes from the host page's own origin.
          def same_origin?(env)
            site = env["HTTP_SEC_FETCH_SITE"]
            return site == "same-origin" if site

            origin = env["HTTP_ORIGIN"].to_s
            origin.empty? || origin.casecmp?(@host.origin)
          end

          # A JSON answer that no cache keeps.
          # @param status [Integer] the HTTP status
          # @param body [Hash] the JSON-RPC reply or the refusal
          # @return [Array] the Rack triplet
          def answer(status, body)
            [status, { "content-type" => "application/json", "cache-control" => "no-store" }, [JSON.generate(body)]]
          end
        end
      end
    end
  end
end
