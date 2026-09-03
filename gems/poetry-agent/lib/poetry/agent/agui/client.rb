# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Poetry
  module Agent
    module AGUI
      # The HTTP client: POSTs a `RunAgentInput` to an AG-UI endpoint and
      # yields the streamed events as they arrive (stdlib Net::HTTP,
      # `text/event-stream`). One call is one run; the multi-run model
      # (client tools, interrupts) is the caller's loop over {Transcript}.
      class Client
        # Raised for a non-success HTTP status.
        class Error < Poetry::Core::Error
          # @return [Integer]
          attr_reader :status

          def initialize(message, status:)
            super(message)
            @status = status
          end
        end

        # @param url [String] the agent's run endpoint
        # @param headers [Hash{String => String}] extra request headers (auth)
        # @param open_timeout [Numeric] seconds
        # @param read_timeout [Numeric] seconds between chunks
        def initialize(url:, headers: {}, open_timeout: 10, read_timeout: 120)
          @uri = URI(url)
          @headers = headers
          @open_timeout = open_timeout
          @read_timeout = read_timeout
        end

        # Runs the agent and yields every event.
        #
        # @param input [Hash] the wire hash ({RunInput.build})
        # @yieldparam event [Hash]
        # @return [SSE::Parser] the parser (its `errors` list any unreadable lines)
        # @raise [Error] on a non-2xx response
        # @example
        #   client.run(input) { |event| transcript.apply(event) }
        def run(input, &)
          request = Net::HTTP::Post.new(@uri)
          request["Content-Type"] = "application/json"
          request["Accept"] = "text/event-stream"
          @headers.each { |name, value| request[name] = value }
          request.body = JSON.generate(input)

          parser = SSE::Parser.new
          Net::HTTP.start(@uri.host, @uri.port, use_ssl: @uri.scheme == "https",
                                                open_timeout: @open_timeout, read_timeout: @read_timeout) do |http|
            http.request(request) do |response|
              unless response.is_a?(Net::HTTPSuccess)
                raise Error.new("AG-UI endpoint answered #{response.code}", status: response.code.to_i)
              end

              response.read_body { |chunk| parser.feed(chunk, &) }
            end
          end
          parser.finish(&)
          parser
        end
      end
    end
  end
end
