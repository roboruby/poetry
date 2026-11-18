# frozen_string_literal: true

require "test_helper"
require "agui_helper"

module Poetry
  module Agent
    module AGUI
      # The pipeline's own surface: modes, middleware, the failure state,
      # lenient mode's admissions and its taint rule, the key shim, the
      # producer's declared version, the legacy interrupt, era ceilings and
      # the outgoing input. The protocol behaviour itself is pinned by the
      # vectors and the conformance corpus.
      class PipelineTest < Minitest::Test
        START = { "type" => "RUN_STARTED", "threadId" => "t", "runId" => "r" }.freeze
        FINISH = { "type" => "RUN_FINISHED", "threadId" => "t", "runId" => "r" }.freeze

        def feed(events, **)
          AguiHelper.run_pipeline(events, **)
        end

        def test_modes_are_strict_by_default_and_checked
          assert_equal :strict, Pipeline.new.mode
          refute_predicate Pipeline.new, :lenient?
          assert_predicate Pipeline.new(mode: :lenient), :lenient?
          assert_raises(ArgumentError) { Pipeline.new(mode: :loose) }
        end

        def test_middleware_sees_events_after_the_boundary_and_may_split_or_drop_them
          seen = []
          split = lambda do |event|
            seen << event["type"]
            event["type"] == "CUSTOM" ? [] : event
          end
          outcome = feed([START, { "type" => "THINKING_START" }, { "type" => "THINKING_END" },
                          { "type" => "CUSTOM", "name" => "x", "value" => 1 }, FINISH], middleware: [split])

          assert_equal %w[RUN_STARTED REASONING_START REASONING_END CUSTOM RUN_FINISHED], seen,
                       "middleware sees the translated shapes"
          assert_equal(%w[RUN_STARTED REASONING_START REASONING_END RUN_FINISHED], outcome[:events].map do |e|
            e["type"]
          end)
          assert_raises(TypeError) { Pipeline.new(middleware: [->(_event) { "nope" }]).push(START) }
          assert_equal [START], Pipeline.new(middleware: [->(_event) {}, ->(_event) { START }]).push(START) + [START]
        end

        def test_a_strict_rejection_carries_what_preceded_it_and_spends_the_pipeline
          pipeline = Pipeline.new
          pipeline.push(START)
          pipeline.push({ "type" => "TEXT_MESSAGE_CHUNK", "messageId" => "m", "delta" => "a" })
          error = assert_raises(ProtocolError) { pipeline.push(START.merge("runId" => "r2")) }

          assert_equal :verification, error.stage
          assert_equal [{ "type" => "TEXT_MESSAGE_END", "messageId" => "m" }], error.events,
                       "the chunk stream closed before the nested run failed, and that END was delivered"
          again = assert_raises(ProtocolError) { pipeline.push(FINISH) }

          assert_equal error.message, again.message, "the pipeline is spent"
          assert_empty again.events, "nothing is delivered twice"
          assert_empty pipeline.finish

          spent = Pipeline.new
          spent.finish
          assert_raises(ArgumentError) { spent.push(START) }
        end

        def test_finish_invents_nothing_and_a_broken_off_run_reads_truncated
          pipeline = Pipeline.new
          pipeline.push(START)
          pipeline.push({ "type" => "TEXT_MESSAGE_CHUNK", "messageId" => "m", "delta" => "a" })

          assert_empty pipeline.finish
          assert_predicate pipeline, :truncated?
          assert_predicate Pipeline.new, :truncated?, "a stream with no run at all is truncated too"
        end

        def test_lenient_mode_drops_with_a_warning_and_admits_a_well_formed_boundary
          outcome = feed([START,
                          { "type" => "TEXT_MESSAGE_START", "messageId" => "m" },
                          { "type" => "TEXT_MESSAGE_CONTENT", "messageId" => "nope", "delta" => "x" },
                          FINISH, START.merge("runId" => "r2"), START.merge("runId" => "r3"),
                          FINISH.merge("runId" => "r3")], mode: :lenient)

          assert_nil outcome[:error]
          assert_equal(%w[RUN_STARTED TEXT_MESSAGE_START RUN_FINISHED RUN_STARTED RUN_STARTED RUN_FINISHED],
                       outcome[:events].map { |event| event["type"] })
          assert_equal %i[lenient_dropped lenient_admitted lenient_admitted],
                       outcome[:pipeline].warnings.map(&:kind)
        end

        def test_lenient_mode_never_lets_a_damaged_call_finish
          outcome = feed([START,
                          { "type" => "TOOL_CALL_START", "toolCallId" => "c1", "toolCallName" => "book" },
                          { "type" => "TOOL_CALL_ARGS", "toolCallId" => "c1", "delta" => 7 },
                          { "type" => "TOOL_CALL_END", "toolCallId" => "c1" },
                          { "type" => "TOOL_CALL_START", "toolCallId" => "c2", "toolCallName" => "book" },
                          { "type" => "TOOL_CALL_END", "toolCallId" => "c2" },
                          FINISH], mode: :lenient)
          transcript = Transcript.new(client_tools: ["book"])
          outcome[:events].each { |event| transcript.apply(event) }

          assert_equal %w[c2], transcript.pending_client_tools.map { |call| call[:tool_call_id] },
                       "the call that lost its arguments never reaches the browser"
          assert(outcome[:warnings].any? { |warning| warning.include?("withheld TOOL_CALL_END for 'c1'") })
        end

        def test_a_dropped_continuation_chunk_taints_the_open_call
          outcome = feed([START,
                          { "type" => "TOOL_CALL_CHUNK", "toolCallId" => "c1", "toolCallName" => "book",
                            "delta" => "{" },
                          { "type" => "TOOL_CALL_CHUNK", "delta" => 7 },
                          FINISH], mode: :lenient)

          refute_includes outcome[:events].map { |event| event["type"] }, "TOOL_CALL_END"
          assert(outcome[:warnings].any? { |warning| warning.include?("withheld TOOL_CALL_END for 'c1'") })
        end

        def test_lenient_mode_reads_snake_case_keys_once_with_a_warning
          outcome = feed([{ type: "RUN_STARTED", thread_id: "t", run_id: "r" },
                          { "type" => "TEXT_MESSAGE_START", "message_id" => "m", "messageId" => "m" },
                          { type: "RUN_FINISHED", thread_id: "t", run_id: "r", "unknown_key" => 1 }], mode: :lenient)

          assert_nil outcome[:error]
          assert_equal({ "type" => "RUN_FINISHED", "threadId" => "t", "runId" => "r" }, outcome[:events].last)
          assert_equal 3, outcome[:pipeline].warnings.count { |warning| warning.kind == :key_shim },
                       ":type, :thread_id and :run_id, each once; a key the event already carries is left alone"
          strict = feed([{ type: "RUN_STARTED", thread_id: "t", run_id: "r" }])

          assert_empty strict[:events], "strict mode reads the wire as it is: no \"type\" key, no event it knows"
          assert_equal [:unrecognised_event], strict[:pipeline].warnings.map(&:kind)
        end

        def test_the_producers_declared_version_is_served_and_named_when_newer
          warnings = ->(version) { feed([START.merge("protocolVersion" => version), FINISH])[:warnings] }

          assert_empty warnings.call("1.0")
          assert_empty warnings.call("0.9")
          assert_includes warnings.call("1.1").first, "speaks protocol 1.1"
          assert_includes warnings.call("next").first, "cannot interpret"
        end

        def test_the_legacy_interrupt_is_named_only_when_the_run_then_finishes_without_the_outcome
          custom = { "type" => "CUSTOM", "name" => "on_interrupt", "value" => {} }
          interrupt = { "type" => "interrupt", "interrupts" => [{ "id" => "i1", "reason" => "approval" }] }

          assert_equal [:legacy_interrupt], feed([START, custom, FINISH])[:pipeline].warnings.map(&:kind)
          assert_empty feed([START, custom, FINISH.merge("outcome" => interrupt)])[:warnings]
          assert_empty feed([START, custom, { "type" => "RUN_ERROR", "message" => "x" }, START, FINISH])[:warnings]
        end

        def test_a_string_outside_a_closed_set_is_stripped_not_fatal
          outcome = feed([START,
                          { "type" => "TEXT_MESSAGE_START", "messageId" => "m", "role" => "narrator" },
                          { "type" => "TEXT_MESSAGE_END", "messageId" => "m" },
                          { "type" => "REASONING_ENCRYPTED_VALUE", "subtype" => "step", "entityId" => "m",
                            "encryptedValue" => "x" },
                          FINISH])

          assert_nil outcome[:error]
          assert_equal({ "type" => "TEXT_MESSAGE_START", "messageId" => "m" }, outcome[:events][1],
                       "an optional role it does not name is removed")
          refute(outcome[:events].any? { |event| event["type"] == "REASONING_ENCRYPTED_VALUE" },
                 "a required subtype it does not name removes the event")
          assert_includes outcome[:warnings], "Removed unrecognised material at '/role' on TEXT_MESSAGE_START."
          assert_includes outcome[:warnings],
                          "Dropping REASONING_ENCRYPTED_VALUE: its required '/subtype' holds a value this " \
                          "implementation does not recognise."
          refute_nil feed([START, { "type" => "TEXT_MESSAGE_START", "messageId" => "m", "role" => 7 }])[:error],
                     "a role that is not a string stays malformed"
        end

        def test_a_ceiling_installs_its_era_and_must_be_a_version
          assert_raises(ArgumentError) { Pipeline.new(max_protocol_version: "v1") }
          outcome = feed([START, { "type" => "SUBAGENT_STARTED", "subagentRunId" => "s1", "name" => "child" }, FINISH],
                         max_protocol_version: "0.0.57")

          assert_equal(%w[RUN_STARTED RUN_FINISHED], outcome[:events].map { |event| event["type"] })
          assert_includes outcome[:warnings].first, "predates subagent support"
        end

        def test_outgoing_upgrades_downgrades_and_enforces_without_touching_the_input
          input = RunInput.build(thread_id: "t", run_id: "r", parent_run_id: "p", messages: [
                                   RunInput.user_message([{ "type" => "text", "text" => "see " },
                                                          { "type" => "binary", "mimeType" => "image/png",
                                                            "data" => "aGk=" }], id: "u")
                                 ])
          original = Marshal.load(Marshal.dump(input))
          current = Pipeline.new.outgoing(input)
          pinned = Pipeline.new(max_protocol_version: "0.0.39")

          assert_equal "image", current["messages"].first["content"].last["type"]
          assert_equal "1.0", current["protocolVersion"]
          assert_equal({ "id" => "u", "role" => "user", "content" => "see " }, pinned.outgoing(input)["messages"].first)
          refute pinned.outgoing(input).key?("protocolVersion")
          refute pinned.outgoing(input).key?("parentRunId")
          assert(pinned.warnings.any? { |warning| warning.kind == :lossy })
          assert_equal original, input
          assert_raises(ProtocolError) { Pipeline.new.outgoing(input.merge("threadId" => 7)) }
        end
      end
    end
  end
end
