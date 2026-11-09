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
          # The HTTP status the relay answered with.
          # @return [Integer]
          attr_reader :status

          # An HTTP failure, with its status.
          #
          # @param message [String] the error message
          # @param status [Integer] the HTTP status the relay answered with
          def initialize(message, status:)
            super(message)
            @status = status
          end
        end

        # A client for an AG-UI endpoint, with its headers and timeouts.
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

        # Runs the agent and yields every VERIFIED event, as AG-UI 1.0's
        # processing model requires of a client that hands events to
        # application code. The input is prepared on the way out
        # ({Pipeline#outgoing}: unrecognised material stripped with a warning,
        # a malformed known field fatal before anything is sent), and the
        # stream goes through the pipeline on the way in.
        #
        # @param input [Hash] the wire hash ({RunInput.build})
        # @param pipeline [Pipeline] the consumer pipeline (strict unless given a lenient one)
        # @yieldparam event [Hash] a verified event
        # @return [Pipeline] the pipeline: its `warnings`, and `truncated?` for a run that broke off
        # @raise [Error] on a non-2xx response
        # @raise [ProtocolError] for a malformed input, an undecodable frame, or a stream the client rejects
        # @example
        #   client.run(input) { |event| transcript.apply(event) }
        def run(input, pipeline: Pipeline.new, &block)
          request = Net::HTTP::Post.new(@uri)
          request["Content-Type"] = "application/json"
          request["Accept"] = "text/event-stream"
          @headers.each { |name, value| request[name] = value }
          request.body = JSON.generate(pipeline.outgoing(input))

          parser = SSE::Parser.new
          deliver = lambda do |raw|
            pipeline.push(raw).each { |event| block&.call(event) }
          rescue ProtocolError => e
            e.events.each { |event| block&.call(event) } # what preceded the failure was delivered
            raise
          end
          Net::HTTP.start(@uri.host, @uri.port, use_ssl: @uri.scheme == "https",
                                                open_timeout: @open_timeout, read_timeout: @read_timeout) do |http|
            http.request(request) do |response|
              unless response.is_a?(Net::HTTPSuccess)
                raise Error.new("AG-UI endpoint answered #{response.code}", status: response.code.to_i)
              end

              response.read_body do |chunk|
                parser.feed(chunk, &deliver)
                undecodable!(parser)
              end
            end
          end
          parser.finish(&deliver)
          undecodable!(parser)
          pipeline.finish.each { |event| block&.call(event) }
          pipeline
        end

        private

        # A frame that maps to no event fails the run: dropping it silently
        # could hide a lost RUN_FINISHED or tool call.
        def undecodable!(parser)
          return if parser.errors.empty?

          raise ProtocolError.new("An SSE frame is not a JSON object: #{parser.errors.first[0, 120].inspect}",
                                  stage: :transport)
        end
      end
    end
  end
end
