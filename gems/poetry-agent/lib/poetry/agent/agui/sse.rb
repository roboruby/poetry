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
          # The largest frame it buffers, as the reference client caps it.
          MAX_FRAME_BYTES = 10 * 1024 * 1024

          # Frames whose data the parser could not read as a JSON object.
          # Turning bytes into events is the reader's job, and a frame that maps
          # to no event is a decode failure: {Client#run} fails the run on one.
          #
          # @return [Array<String>]
          attr_reader :errors

          # A parser with an empty buffer and no pending data.
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
          # @raise [ProtocolError] when a frame outgrows {MAX_FRAME_BYTES}
          def feed(chunk, &)
            @buffer << chunk
            if @buffer.bytesize + @data.sum(&:bytesize) > MAX_FRAME_BYTES
              raise ProtocolError.new("An SSE frame exceeded #{MAX_FRAME_BYTES} bytes", stage: :transport)
            end

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

          # Consumes one line: a blank dispatches the pending event, a data line adds to it.
          def consume(line, &)
            if line.empty?
              dispatch(&)
            elsif line.start_with?("data:")
              @data << line.delete_prefix("data:").delete_prefix(" ")
            end
            # Comments (":"), event:, id:, retry: carry nothing AG-UI reads.
          end

          # Parses the pending data lines as one JSON event and yields it; a parse error is recorded.
          def dispatch
            return if @data.empty?

            payload = @data.join("\n")
            @data = []
            event = JSON.parse(payload)
            return @errors << payload unless event.is_a?(Hash)

            yield event if block_given?
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
