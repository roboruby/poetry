# frozen_string_literal: true

module Poetry
  module Agent
    module AGUI
      # A stream the client rejects: a protocol violation it detected, kept
      # apart from a run's own RUN_ERROR (a well-formed event, delivered and
      # read as the run's status). AG-UI 1.0 makes a malformed known value, a
      # broken open/close discipline and a broken run lifecycle fatal.
      #
      # @example
      #   begin
      #     client.run(input) { |event| relay.transcript.apply(event) }
      #   rescue Poetry::Agent::AGUI::ProtocolError => e
      #     e.stage # => :verification
      #     e.message # => "Cannot send 'RUN_FINISHED' while tool calls are still active: c1"
      #   end
      class ProtocolError < Poetry::Core::Error
        # Who rejected the stream: :enforcement, :expansion, :verification or :transport.
        #
        # @return [Symbol, nil]
        attr_reader :stage

        # The two rejections of a well-formed run boundary that lenient mode
        # admits instead of dropping (:open_at_finish, :nested_run); nil otherwise.
        #
        # @return [Symbol, nil]
        attr_reader :kind

        # The verified events of the same push that preceded the rejection:
        # the reference client delivers each one before the error, so a caller
        # wanting that incremental contract applies them before handling it.
        #
        # @return [Array<Hash>]
        attr_reader :events

        # A rejection with what rejected it.
        #
        # @param message [String, nil]
        # @param stage [Symbol, nil]
        # @param kind [Symbol, nil]
        # @param events [Array<Hash>]
        def initialize(message = nil, stage: nil, kind: nil, events: [])
          super(message)
          @stage = stage
          @kind = kind
          @events = events
        end

        # The same rejection, carrying the events delivered before it.
        #
        # @param events [Array<Hash>]
        # @return [ProtocolError]
        def with_events(events)
          dup.tap { |copy| copy.instance_variable_set(:@events, events) }
        end
      end

      # Something the pipeline, the run input's enforcement or the transcript
      # removed, translated, tolerated or could not apply. AG-UI 1.0 requires
      # these be surfaced, never silenced by default: each goes to the
      # `on_warning:` callback and is collected.
      #
      # Kinds: :unrecognised_event, :stripped, :translated, :lossy,
      # :producer_version, :lenient_dropped, :lenient_admitted, :key_shim,
      # :legacy_interrupt, :patch_failed, :activity_missing.
      #
      # @example
      #   Poetry::Agent::AGUI::ProtocolWarning.new(kind: :stripped, message: "Removed ... at '/x' on RUN_STARTED.")
      ProtocolWarning = Data.define(:kind, :message) do
        # The warning's sentence.
        # @return [String]
        def to_s = message
      end
    end
  end
end
