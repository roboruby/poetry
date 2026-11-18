# frozen_string_literal: true

module Poetry
  module Agent
    module AGUI
      # The AG-UI 1.0 processing pipeline, in the order the specification
      # fixes:
      #
      #   compatibility boundary -> middleware -> enforcement -> chunk expansion -> verification -> application
      #
      # One instance per stream; {Client#run} and {Relay} each hold one.
      # Everything it returns is verified, expanded and camelCase, so the
      # {Transcript} is a plain reducer of it. In strict mode (the conformant
      # default) a rejection raises {ProtocolError}; the opt-in lenient mode,
      # for developing against an agent that is not yet conformant, drops the
      # offending event with a warning instead, and reads snake_case keys.
      #
      # @example Feeding a stream by hand
      #   pipeline = Poetry::Agent::AGUI::Pipeline.new(on_warning: ->(warning) { Rails.logger.report(warning.message) })
      #   SSE.parse(body) { |raw| pipeline.push(raw).each { |event| transcript.apply(event) } }
      #   pipeline.finish
      class Pipeline
        # The two modes: conformant, and tolerant for development.
        MODES = %i[strict lenient].freeze
        # Rejections of a well-formed run boundary caused by what came before it.
        BOUNDARY_KINDS = %i[open_at_finish nested_run].freeze

        # The described properties per event type, for the lenient key shim.
        #
        # @return [Hash{String => Set<String>}]
        # @api private
        def self.described
          @described ||= begin
            table = Enforcement::Walker.default.table
            defs = table.fetch("defs")
            defs.fetch(table.dig("roots", "event")).fetch("members").to_h do |type, name|
              [type, defs.fetch(name).fetch("props").keys.to_set.freeze]
            end.freeze
          end
        end

        # :strict or :lenient.
        #
        # @return [Symbol]
        attr_reader :mode

        # Every warning this stream raised, in order.
        #
        # @return [Array<ProtocolWarning>]
        attr_reader :warnings

        # A pipeline for one stream.
        #
        # @param mode [Symbol] :strict (conformant; a rejection raises) or :lenient (drop and warn)
        # @param on_warning [#call, nil] receives each {ProtocolWarning} as it happens
        # @param middleware [Array<#call>] `(event) -> Array<event>`, run after the
        #   compatibility boundary and before enforcement, so they see what the producer sent
        # @param max_protocol_version [String, nil] the agent's protocol version when it is known
        #   to be older than this client's ("0.0.57", say): the era shims for it are installed,
        #   both ways. nil treats the agent as current
        # @raise [ArgumentError] for an unknown mode, or a version that is not dot-separated numbers
        def initialize(mode: :strict, on_warning: nil, middleware: [], max_protocol_version: nil)
          raise ArgumentError, "mode must be :strict or :lenient, not #{mode.inspect}" unless MODES.include?(mode)

          @mode = mode
          @on_warning = on_warning
          @warnings = []
          @era = Shims::Era.new(max_protocol_version, method(:report))
          @middleware = Array(middleware) + @era.inbound
          @walker = Enforcement::Walker.default
          @compatibility = Compatibility.new(method(:report))
          @chunks = ChunkExpansion.new
          @verification = Verification.new
          @shimmed = Set.new
          @legacy_interrupt = false
          @tainted = Set.new
          @failure = nil
          @finished = false
        end

        # One raw event in; the verified events application code receives, in
        # order (zero or more). In strict mode a rejection raises, carrying the
        # events of this push that preceded it ({ProtocolError#events}: they
        # are delivered, so hand them on); the pipeline is then spent and every
        # later push raises the same failure, carrying no events.
        #
        # @param event [Hash] a parsed wire event
        # @return [Array<Hash>]
        # @raise [ProtocolError]
        def push(event)
          raise @failure.with_events([]) if @failure
          raise ArgumentError, "push after finish" if @finished

          delivered = []
          begin
            through_middleware(@compatibility.call(event)).each { |raw| process(raw, delivered) }
          rescue ProtocolError => e
            @failure = e.with_events(delivered)
            raise @failure
          end
          delivered
        end

        # The end of the stream. Nothing is synthesized: a chunk stream still
        # open is dropped rather than closed, and a run without its terminal
        # event stays truncated (the spec forbids inventing RUN_FINISHED).
        #
        # @return [Array<Hash>] always empty
        def finish
          return [] if @failure || @finished

          @finished = true
          @chunks.finish
        end

        # The run input as it should be sent to this pipeline's agent. Legacy
        # binary content parts become media parts; for an agent pinned to an
        # older version the era shims downgrade it (warning about whatever the
        # agent cannot receive) and the `protocolVersion` declaration is left
        # out where the agent predates it; then it is enforced - unrecognised
        # material stripped with a warning, a null in an optional field read as
        # absent, a malformed known field fatal before anything is sent. The
        # input itself is never changed.
        #
        # @param input [Hash] a wire hash ({RunInput.build})
        # @return [Hash] the input to send
        # @raise [ProtocolError] for a malformed known field
        def outgoing(input)
          input = @era.outgoing(LegacyContent.upgrade_input(input, method(:report)))
          input = input.except("protocolVersion") if input.is_a?(Hash) && !@era.declares_protocol_version?
          @walker.input(input) { |warning| report(warning) }
        end

        # Whether the stream ended with a run still open, or with no run at all.
        # @return [Boolean]
        def truncated? = @verification.run_open? || !@verification.seen?

        # Whether this pipeline drops and warns instead of rejecting.
        # @return [Boolean]
        def lenient? = @mode == :lenient

        # Records a warning and hands it to the callback.
        #
        # @param warning [ProtocolWarning]
        # @return [void]
        # @api private
        def report(warning)
          @warnings << warning
          @on_warning&.call(warning)
        end

        private

        # Reports a warning of a kind.
        def say(kind, message) = report(ProtocolWarning.new(kind: kind, message: message))

        # Runs each middleware over the events the previous one returned.
        def through_middleware(event)
          @middleware.reduce([event]) do |events, middleware|
            events.flat_map do |each|
              result = middleware.call(each)
              case result
              when nil then []
              when Array then result
              when Hash then [result]
              else raise TypeError, "middleware must return an Array of events, not #{result.class}"
              end
            end
          end
        end

        # One event through enforcement, expansion and verification.
        def process(raw, delivered)
          raw = shim_keys(raw) if lenient?
          event = enforce(raw) or return
          expanded = expand(event) or return
          expanded.each do |each|
            verified = verify(each) or next
            next if withheld?(verified)

            delivered << verified
            declared_version(verified) if verified["type"] == "RUN_STARTED"
            legacy_interrupt(verified)
          end
        end

        # Strips and drops unrecognised material; a malformed value is a rejection.
        def enforce(raw)
          @walker.event(raw) { |warning| report(warning) }
        rescue ProtocolError => e
          reject(e, raw)
        end

        # Chunk events become the start, content and end form.
        def expand(event)
          @chunks.call(event)
        rescue ProtocolError => e
          reject(e, event)
        end

        # The lifecycle and open/close discipline; lenient mode admits a
        # well-formed run boundary and abandons what the run left open.
        def verify(event)
          @verification.call(event)
        rescue ProtocolError => e
          raise unless lenient?
          return reject(e, event) unless BOUNDARY_KINDS.include?(e.kind)

          # A well-formed run boundary is never dropped for state it did not
          # create: dropping RUN_FINISHED would leave every later run nested.
          say(:lenient_admitted, "Lenient mode admitted #{event["type"]} and abandoned what the run left open: " \
                                 "#{e.message}")
          @verification.abandon!(e.kind)
          @verification.call(event)
        end

        # Strict: raise. Lenient: drop the event with a warning naming why,
        # and mark the tool call it belonged to as damaged.
        def reject(error, event)
          raise error unless lenient?

          type = event.is_a?(Hash) ? event["type"] : nil
          say(:lenient_dropped, "Lenient mode dropped #{type || "an event"}: #{error.message}")
          taint(event) if type.to_s.start_with?("TOOL_CALL_") && type != "TOOL_CALL_RESULT"
          nil
        end

        # A tool call that lost an event has arguments nobody can trust: the
        # one the event names, or every call open when it names none (a
        # continuation chunk).
        def taint(event)
          id = event["toolCallId"] || event[:toolCallId] || event["tool_call_id"] || event[:tool_call_id]
          id.is_a?(String) ? @tainted << id : @tainted.merge(@verification.open_tool_calls)
        end

        # Lenient mode never hands a damaged call on: its END is withheld, so
        # the call is never settled and never runs. The END still passed
        # verification, which keeps the stream's bookkeeping whole.
        def withheld?(event)
          return false unless event["type"] == "TOOL_CALL_END" && @tainted.delete?(event["toolCallId"])

          say(:lenient_dropped, "Lenient mode withheld TOOL_CALL_END for '#{event["toolCallId"]}': an event of this " \
                                "call was dropped, so its arguments are incomplete and the call will not run.")
          true
        end

        # Lenient only: a top-level snake_case or Symbol key read as the
        # camelCase field it names, when the event type describes that field
        # and the event does not already carry it. Warned once per key per
        # stream. Nested keys (messages, outcome, interrupts) are not touched.
        def shim_keys(raw)
          return raw unless raw.is_a?(Hash) && raw.each_key.any? { |key| !key.is_a?(String) || key.include?("_") }

          described = self.class.described[(raw["type"] || raw[:type]).to_s] || Set.new
          raw.each_with_object({}) do |(key, value), out|
            name = key.to_s
            camel = name.gsub(/_([a-z\d])/) { Regexp.last_match(1).upcase }
            if (key.is_a?(String) && camel == name) || !described.include?(camel) || raw.key?(camel)
              out[key.is_a?(Symbol) && !raw.key?(name) ? name : key] = value
              next
            end
            if @shimmed.add?(key)
              say(:key_shim, "Lenient mode read the key #{key.inspect} as '#{camel}'; the wire is camelCase strings.")
            end
            out[camel] = value
          end
        end

        # The producer's RUN_STARTED declaration against what this client
        # speaks: older or absent passes quietly; newer or uninterpretable is
        # served, and warned about.
        def declared_version(event)
          declared = event["protocolVersion"]
          return if declared.nil? || declared == PROTOCOL_VERSION

          unless declared.match?(/\A\d+\.\d+\z/)
            return say(:producer_version, "The producer declared protocol version '#{declared}', which this client " \
                                          "cannot interpret.")
          end
          return unless Shims.compare(declared, PROTOCOL_VERSION).positive?

          say(:producer_version, "The producer speaks protocol #{declared}; this client speaks #{PROTOCOL_VERSION}. " \
                                 "Unrecognised material will be stripped with warnings.")
        end

        # A CUSTOM `on_interrupt` is how some integrations signalled an
        # interrupt before AG-UI 1.0. One that also ends its run with the 1.0
        # interrupt outcome is fine; one whose run finishes without it reads
        # as finished, so the thread stalls - that is the case to name.
        def legacy_interrupt(event)
          case event["type"]
          when "RUN_STARTED" then @legacy_interrupt = false
          when "CUSTOM" then @legacy_interrupt = true if event["name"] == "on_interrupt"
          when "RUN_FINISHED"
            stalled = @legacy_interrupt && event.dig("outcome", "type") != "interrupt"
            @legacy_interrupt = false
            stalled_interrupt if stalled
          end
        end

        # The warning for a run that signalled an interrupt only the pre-1.0 way.
        def stalled_interrupt
          say(:legacy_interrupt, "The agent signalled an interrupt with a CUSTOM 'on_interrupt' event, the pre-1.0 " \
                                 "way; this client reads the interrupt outcome on RUN_FINISHED, so the run reads as " \
                                 "finished. Configure the agent to end the run with the interrupt outcome " \
                                 "(ag-ui-langgraph: emit_interrupt_outcome=True).")
        end
      end
    end
  end
end
