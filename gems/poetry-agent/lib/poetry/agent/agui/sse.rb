# frozen_string_literal: true

require "json"

module Poetry
  module Agent
    module AGUI
      # A `text/event-stream` parser for AG-UI: every event is a JSON
      # object on one or more `data:` lines, terminated by a blank line.
      # Incremental (feed chunks as they arrive) and tolerant of comments,
      # `event:` / `id:` / `retry:` fields, and CRLF.
      module SSE
        # The incremental parser.
        class Parser
          # Lines that carried data the parser could not read as JSON.
          #
          # @return [Array<String>]
          attr_reader :errors

          def initialize
            @buffer = +""
            @data = []
            @errors = []
          end

          # Feeds a chunk and yields each completed event.
          #
          # @param chunk [String]
          # @yieldparam event [Hash] the parsed JSON object (string keys)
          # @return [void]
          def feed(chunk, &)
            @buffer << chunk
            while (newline = @buffer.index("\n"))
              line = @buffer.slice!(0..newline).chomp
              consume(line, &)
            end
          end

          # Flushes a trailing event that lacked its blank line.
          #
          # @yieldparam event [Hash]
          # @return [void]
          def finish(&)
            consume(@buffer.chomp, &) unless @buffer.empty?
            @buffer = +""
            dispatch(&)
          end

          private

          def consume(line, &)
            if line.empty?
              dispatch(&)
            elsif line.start_with?("data:")
              @data << line.delete_prefix("data:").delete_prefix(" ")
            end
            # Comments (":"), event:, id:, retry: carry nothing AG-UI reads.
          end

          def dispatch
            return if @data.empty?

            payload = @data.join("\n")
            @data = []
            event = JSON.parse(payload)
            yield event if event.is_a?(Hash) && block_given?
          rescue JSON::ParserError
            @errors << payload
          end
        end

        module_function

        # Parses a complete stream (a String or anything responding to
        # `each` with chunks) and yields every event.
        #
        # @param source [String, #each]
        # @yieldparam event [Hash]
        # @return [Array<Hash>] every event, when no block is given
        # @example
        #   Poetry::Agent::AGUI::SSE.parse("data: {\"type\":\"RUN_STARTED\"}\n\n") # => [{ "type" => "RUN_STARTED" }]
        def parse(source, &block)
          events = []
          collector = block || ->(event) { events << event }
          parser = Parser.new
          if source.is_a?(String)
            parser.feed(source, &collector)
          else
            source.each { |chunk| parser.feed(chunk.to_s, &collector) }
          end
          parser.finish(&collector)
          block ? nil : events
        end
      end
    end
  end
end
