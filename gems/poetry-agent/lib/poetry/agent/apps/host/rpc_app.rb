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
        # Rack app sees no CSRF token; an application that needs the
        # signed-in user's credentials calls {Host#rpc} from a controller of
        # its own instead and passes the headers.
        class RpcApp
          # The endpoint for one host.
          # @param host [Host] the host whose servers it relays to
          def initialize(host)
            @host = host
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
            result = @host.rpc(body.fetch("server").to_s, body.fetch("method").to_s, body["params"] || {})
            answer(200, { "result" => result })
          rescue JSON::ParserError, KeyError
            answer(400,
                   { "error" => { "code" => -32_700, "message" => "a JSON object with server, method and params" } })
          rescue Refused => e
            answer(403, { "error" => { "code" => e.code, "message" => e.message } })
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
