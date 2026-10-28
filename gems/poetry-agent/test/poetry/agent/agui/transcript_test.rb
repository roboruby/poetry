# frozen_string_literal: true

require "test_helper"

module Poetry
  module Agent
    module AGUI
      class TranscriptTest < Minitest::Test
        def scripted_run
          [
            { "type" => "RUN_STARTED", "threadId" => "t1", "runId" => "r1" },
            { "type" => "REASONING_MESSAGE_START", "messageId" => "m1" },
            { "type" => "REASONING_MESSAGE_CONTENT", "messageId" => "m1", "delta" => "Think." },
            { "type" => "REASONING_MESSAGE_END", "messageId" => "m1" },
            { "type" => "TEXT_MESSAGE_START", "messageId" => "m1", "role" => "assistant" },
            { "type" => "TEXT_MESSAGE_CONTENT", "messageId" => "m1", "delta" => "Hello " },
            { "type" => "TEXT_MESSAGE_CONTENT", "messageId" => "m1", "delta" => "world" },
            { "type" => "TEXT_MESSAGE_END", "messageId" => "m1" },
            { "type" => "TOOL_CALL_START", "toolCallId" => "c1", "toolCallName" => "lookup",
              "parentMessageId" => "m1" },
            { "type" => "TOOL_CALL_ARGS", "toolCallId" => "c1", "delta" => "{\"q\":" },
            { "type" => "TOOL_CALL_ARGS", "toolCallId" => "c1", "delta" => "\"plans\"}" },
            { "type" => "TOOL_CALL_END", "toolCallId" => "c1" },
            { "type" => "TOOL_CALL_RESULT", "messageId" => "m1-r", "toolCallId" => "c1", "content" => "{\"count\":3}" },
            { "type" => "STATE_SNAPSHOT", "snapshot" => { "plans" => [] } },
            { "type" => "STATE_DELTA", "delta" => [{ "op" => "add", "path" => "/plans/-", "value" => "team" }] },
            { "type" => "TOOL_CALL_START", "toolCallId" => "c2", "toolCallName" => "poetry.sections.set_value",
              "parentMessageId" => "m1" },
            { "type" => "TOOL_CALL_ARGS", "toolCallId" => "c2", "delta" => "{\"value\":\"pricing\"}" },
            { "type" => "TOOL_CALL_END", "toolCallId" => "c2" },
            { "type" => "RUN_FINISHED", "threadId" => "t1", "runId" => "r1" }
          ]
        end

        def test_folds_a_run_into_parts_state_and_pending_client_tools
          transcript = Transcript.new(client_tools: ["poetry.sections.set_value"]).apply_all(scripted_run)
          message = transcript.message("m1")

          assert_equal(%i[reasoning text tool tool], message.parts.map { |part| part[:kind] })
          assert_equal "assistant", message.role, "text on a reasoning message's id makes it an assistant message"
          assert_equal "Think.", message.parts[0][:text]
          assert_equal "Hello world", message.parts[1][:text]
          assert_equal({ "q" => "plans" }, message.parts[2][:input])
          assert_equal({ "count" => 3 }, message.parts[2][:output])
          assert_equal :done, message.parts[2][:state]
          assert_equal :awaiting_client, message.parts[3][:state]
          assert_equal({ "plans" => ["team"] }, transcript.state)
          pending = { tool_call_id: "c2", name: "poetry.sections.set_value", input: { "value" => "pricing" },
                      message_id: "m1" }

          assert_equal [pending],
                       transcript.pending_client_tools
          assert_equal :finished, transcript.run[:status]
          assert_predicate transcript, :ended?
          assert_operator message.version, :>, 10
        end

        def test_apply_names_the_changed_messages_and_versions_climb
          transcript = Transcript.new
          versions = scripted_run.map do |event|
            changed = transcript.apply(event)
            [changed, transcript.version]
          end

          assert_equal ["m1"], versions[1].first
          assert_equal [], versions[0].first
          assert_equal versions.map(&:last), versions.map(&:last).sort
        end

        def test_client_tool_resolution_feeds_the_next_run_input
          transcript = Transcript.new(client_tools: ["poetry.sections.set_value"]).apply_all(scripted_run)
          transcript.resolve_client_tool("c2", "{\"value\":\"pricing\",\"changed\":true}")

          assert_empty transcript.pending_client_tools
          assert_equal :done, transcript.message("m1").parts[3][:state]
          wire = transcript.messages_for_input

          assert_equal(%w[assistant tool tool], wire.map { |message| message["role"] })
          assert_equal "Hello world", wire[0]["content"]
          lookup = { "id" => "c1", "type" => "function",
                     "function" => { "name" => "lookup", "arguments" => "{\"q\":\"plans\"}" } }

          assert_equal [lookup,
                        { "id" => "c2", "type" => "function",
                          "function" => { "name" => "poetry.sections.set_value",
                                          "arguments" => "{\"value\":\"pricing\"}" } }],
                       wire[0]["toolCalls"]
          assert_equal({ "id" => "c2-result", "role" => "tool", "content" => "{\"value\":\"pricing\",\"changed\":true}",
                         "toolCallId" => "c2" }, wire[2])
        end

        def test_interrupts_errors_chunks_activities_and_unknowns
          pipeline = Pipeline.new
          transcript = Transcript.new
          [
            { "type" => "RUN_STARTED", "threadId" => "t", "runId" => "r" },
            { "type" => "TEXT_MESSAGE_CHUNK", "messageId" => "m9", "delta" => "chunked" },
            { "type" => "TOOL_CALL_CHUNK", "toolCallId" => "c9", "toolCallName" => "book",
              "parentMessageId" => "m9", "delta" => "{\"a\":1}" },
            { "type" => "ACTIVITY_SNAPSHOT", "messageId" => "act", "activityType" => "PLAN",
              "content" => { "steps" => [] } },
            { "type" => "ACTIVITY_DELTA", "messageId" => "act", "activityType" => "PLAN",
              "patch" => [{ "op" => "add", "path" => "/steps/-", "value" => "one" }] },
            { "type" => "CUSTOM", "name" => "ping", "value" => 1 },
            { "type" => "NOT_A_THING" },
            { "type" => "RUN_FINISHED", "threadId" => "t", "runId" => "r",
              "outcome" => { "type" => "interrupt",
                             "interrupts" => [{ "id" => "i1", "reason" => "approval", "message" => "Book it?" }] } }
          ].each { |raw| pipeline.push(raw).each { |event| transcript.apply(event) } }

          assert_equal "chunked", transcript.message("m9").parts[0][:text]
          assert_equal({ "a" => 1 }, transcript.message("m9").parts[1][:input])
          assert_equal({ "steps" => ["one"] }, transcript.activities["act"]["content"])
          assert_equal :activity, transcript.message("act").parts.first[:kind]
          assert_equal [:unrecognised_event], pipeline.warnings.map(&:kind), "the pipeline drops what it cannot read"
          assert_equal 1, transcript.custom_events.size
          assert_predicate transcript, :interrupted?
          assert_equal "Book it?", transcript.interrupts.first["message"]

          errored = Transcript.new
          errored.apply({ "type" => "RUN_STARTED", "threadId" => "t", "runId" => "r" })
          errored.apply({ "type" => "RUN_ERROR", "message" => "boom", "code" => "E1" })

          assert_equal({ message: "boom", code: "E1" }, errored.error)
        end

        def test_messages_snapshot_rebuilds_the_transcript
          transcript = Transcript.new
          transcript.apply({ "type" => "MESSAGES_SNAPSHOT", "messages" => [
                             { "id" => "u1", "role" => "user", "content" => "hi" },
                             { "id" => "a1", "role" => "assistant", "content" => "calling",
                               "toolCalls" => [{ "id" => "c1", "type" => "function",
                                                 "function" => { "name" => "f", "arguments" => "{\"x\":1}" } }] },
                             { "id" => "t1", "role" => "tool", "toolCallId" => "c1", "content" => "ok" },
                             { "id" => "r1", "role" => "reasoning", "content" => "why" }
                           ] })

          assert_equal %w[u1 a1 r1], transcript.messages.map(&:id)
          tool = transcript.message("a1").parts.last

          assert_equal({ "x" => 1 }, tool[:input])
          assert_equal "ok", tool[:output]
          assert_equal :done, tool[:state]
          assert_equal :reasoning, transcript.message("r1").parts.first[:kind]
          assert_equal :done, transcript.message("r1").parts.first[:state], "a snapshot's parts arrive whole"
          assert_equal :done, transcript.message("a1").parts.first[:state]
        end

        def test_text_and_reasoning_parts_stream_until_they_close
          transcript = Transcript.new
          transcript.apply({ "type" => "REASONING_MESSAGE_START", "messageId" => "m1" })
          transcript.apply({ "type" => "REASONING_MESSAGE_CONTENT", "messageId" => "m1", "delta" => "Think." })

          assert_equal :streaming, transcript.message("m1").parts[0][:state]
          assert_equal ["m1"], transcript.apply({ "type" => "REASONING_MESSAGE_END", "messageId" => "m1" }),
                       "closing a part re-renders its row"
          assert_equal :done, transcript.message("m1").parts[0][:state]
          assert_empty transcript.apply({ "type" => "REASONING_MESSAGE_END", "messageId" => "m1" }),
                       "a second END closes nothing"

          transcript.apply({ "type" => "TEXT_MESSAGE_START", "messageId" => "m2" })
          transcript.apply({ "type" => "TEXT_MESSAGE_CONTENT", "messageId" => "m2", "delta" => "Hi" })

          assert_equal :streaming, transcript.message("m2").parts[0][:state]
          assert_equal ["m2"], transcript.apply({ "type" => "RUN_ERROR", "message" => "lost the model" }),
                       "a RUN_ERROR ends the run mid-message, and the part closes"
          assert_equal :done, transcript.message("m2").parts[0][:state]
        end

        def test_a_run_error_mid_call_abandons_the_call_instead_of_running_it
          transcript = Transcript.new(client_tools: ["poetry.tabs.set"])
          transcript.apply_all([
                                 { "type" => "RUN_STARTED", "threadId" => "t", "runId" => "r" },
                                 { "type" => "TOOL_CALL_START", "toolCallId" => "c1",
                                   "toolCallName" => "poetry.tabs.set", "parentMessageId" => "a1" },
                                 { "type" => "TOOL_CALL_ARGS", "toolCallId" => "c1", "delta" => "{\"value\":" },
                                 { "type" => "RUN_ERROR", "message" => "boom" }
                               ])

          assert_empty transcript.pending_client_tools, "arguments that never closed are never acted on"
          assert_equal :loading, transcript.message("a1").parts.first[:state]
        end

        def test_unprocessed_events_are_refused_with_the_way_through
          error = assert_raises(ArgumentError) { Transcript.new.apply({ "type" => "TEXT_MESSAGE_CHUNK" }) }

          assert_includes error.message, "Pipeline"
        end

        # Runs a run's events through a strict pipeline into a fresh transcript,
        # as Client#run and Relay do.
        def replay(events, client_tools: [])
          pipeline = Pipeline.new
          transcript = Transcript.new(client_tools: client_tools)
          [{ "type" => "RUN_STARTED", "threadId" => "t", "runId" => "r" }, *events,
           { "type" => "RUN_FINISHED", "threadId" => "t", "runId" => "r" }].each do |raw|
            pipeline.push(raw).each { |event| transcript.apply(event) }
          end
          transcript
        end

        def test_a_reasoning_message_is_its_own_message_and_travels_back
          transcript = replay([
                                { "type" => "REASONING_MESSAGE_START", "messageId" => "r1", "role" => "reasoning" },
                                { "type" => "REASONING_MESSAGE_CONTENT", "messageId" => "r1",
                                  "delta" => "Weighing it." },
                                { "type" => "REASONING_MESSAGE_END", "messageId" => "r1" },
                                { "type" => "TEXT_MESSAGE_START", "messageId" => "m1" },
                                { "type" => "TEXT_MESSAGE_CONTENT", "messageId" => "m1", "delta" => "Done." },
                                { "type" => "TEXT_MESSAGE_END", "messageId" => "m1" }
                              ])

          assert_equal %w[reasoning assistant], transcript.messages.map(&:role)
          assert_equal [{ "id" => "r1", "role" => "reasoning", "content" => "Weighing it." },
                        { "id" => "m1", "role" => "assistant", "content" => "Done." }], transcript.messages_for_input
        end

        def test_a_call_without_a_parent_gets_its_own_assistant_message
          transcript = replay([
                                { "type" => "TEXT_MESSAGE_START", "messageId" => "m1" },
                                { "type" => "TEXT_MESSAGE_END", "messageId" => "m1" },
                                { "type" => "TOOL_CALL_START", "toolCallId" => "c1", "toolCallName" => "now" },
                                { "type" => "TOOL_CALL_END", "toolCallId" => "c1" }
                              ])

          assert_equal %w[m1 c1], transcript.messages.map(&:id), "the reference client's rule, not the current message"
          assert_equal "assistant", transcript.message("c1").role
        end

        def test_arguments_travel_exactly_as_they_streamed
          transcript = replay([
                                { "type" => "TOOL_CALL_START", "toolCallId" => "c1", "toolCallName" => "now",
                                  "parentMessageId" => "m1" },
                                { "type" => "TOOL_CALL_END", "toolCallId" => "c1" }
                              ])
          call = transcript.messages_for_input.first["toolCalls"].first

          assert_equal "", call["function"]["arguments"], "no arguments streamed, none sent (not a JSON string)"
          assert_equal({}, transcript.message("m1").parts.first[:input])
        end

        def test_a_reopened_call_appends_its_arguments
          transcript = replay([
                                { "type" => "TOOL_CALL_START", "toolCallId" => "c1", "toolCallName" => "f",
                                  "parentMessageId" => "m1" },
                                { "type" => "TOOL_CALL_ARGS", "toolCallId" => "c1", "delta" => "{\"a\":" },
                                { "type" => "TOOL_CALL_END", "toolCallId" => "c1" },
                                { "type" => "TOOL_CALL_START", "toolCallId" => "c1", "toolCallName" => "f",
                                  "parentMessageId" => "m1" },
                                { "type" => "TOOL_CALL_ARGS", "toolCallId" => "c1", "delta" => "1}" },
                                { "type" => "TOOL_CALL_END", "toolCallId" => "c1" }
                              ])
          parts = transcript.message("m1").parts

          assert_equal 1, parts.size
          assert_equal({ "a" => 1 }, parts.first[:input])
          assert_equal "{\"a\":1}", transcript.messages_for_input.first["toolCalls"].first["function"]["arguments"]
        end

        def test_a_chunked_client_tool_waits_on_the_browser_once_the_run_ends
          transcript = replay([{ "type" => "TOOL_CALL_CHUNK", "toolCallId" => "c1", "toolCallName" => "poetry.tabs.set",
                                 "parentMessageId" => "m1", "delta" => "{\"value\":\"b\"}" }],
                              client_tools: ["poetry.tabs.set"])

          assert_equal :awaiting_client, transcript.message("m1").parts.first[:state]
          assert_equal [{ tool_call_id: "c1", name: "poetry.tabs.set", input: { "value" => "b" }, message_id: "m1" }],
                       transcript.pending_client_tools
        end

        def test_a_tool_result_keeps_its_own_id_and_its_content_parts
          parts = [{ "type" => "text", "text" => "Invoice attached." },
                   { "type" => "document", "source" => { "type" => "url", "value" => "https://example.com/i.pdf" } }]
          transcript = replay([
                                { "type" => "TOOL_CALL_START", "toolCallId" => "c1", "toolCallName" => "invoice",
                                  "parentMessageId" => "a1" },
                                { "type" => "TOOL_CALL_END", "toolCallId" => "c1" },
                                { "type" => "TOOL_CALL_RESULT", "messageId" => "t1", "toolCallId" => "c1",
                                  "content" => parts }
                              ])
          tool = transcript.messages_for_input.last

          assert_equal({ "id" => "t1", "role" => "tool", "content" => parts, "toolCallId" => "c1" }, tool)
        end

        def test_a_snapshot_keeps_content_parts_and_every_conversation_role
          parts = [{ "type" => "text", "text" => "What is this?" },
                   { "type" => "image",
                     "source" => { "type" => "data", "value" => "AAAA", "mimeType" => "image/png" } }]
          transcript = Transcript.new
          transcript.apply({ "type" => "MESSAGES_SNAPSHOT", "messages" => [
                             { "id" => "s1", "role" => "system", "content" => "Be brief." },
                             { "id" => "d1", "role" => "developer", "content" => "Tools first." },
                             { "id" => "u1", "role" => "user", "content" => parts },
                             { "id" => "r1", "role" => "reasoning", "content" => "Looking." }
                           ] })

          assert_equal [{ "id" => "s1", "role" => "system", "content" => "Be brief." },
                        { "id" => "d1", "role" => "developer", "content" => "Tools first." },
                        { "id" => "u1", "role" => "user", "content" => parts },
                        { "id" => "r1", "role" => "reasoning", "content" => "Looking." }], transcript.messages_for_input
          assert_equal(%i[text media], transcript.message("u1").parts.map { |part| part[:kind] })
        end

        def activity(id, content)
          { "type" => "ACTIVITY_SNAPSHOT", "messageId" => id, "activityType" => "x", "content" => content }
        end

        def test_a_snapshot_without_activities_keeps_them_and_one_with_activities_replaces_the_set
          transcript = Transcript.new
          transcript.apply(activity("a1", { "n" => 1 }))
          transcript.apply({ "type" => "MESSAGES_SNAPSHOT", "messages" => [] })

          delta = { "type" => "ACTIVITY_DELTA", "messageId" => "a1", "activityType" => "x",
                    "patch" => [{ "op" => "replace", "path" => "/n", "value" => 2 }] }

          assert_equal ["a1"], transcript.apply(delta), "a snapshot carrying no activity says nothing about them"
          assert_equal({ "n" => 2 }, transcript.activities["a1"]["content"])

          transcript.apply({ "type" => "MESSAGES_SNAPSHOT", "messages" => [
                             { "id" => "a2", "role" => "activity", "activityType" => "x", "content" => {} }
                           ] })

          assert_equal ["a2"], transcript.activities.keys, "one that carries an activity declares the whole set"
          assert_empty transcript.apply({ "type" => "ACTIVITY_DELTA", "messageId" => "a1", "activityType" => "x",
                                          "patch" => [{ "op" => "replace", "path" => "/n", "value" => 3 }] })
          assert_equal ["Skipped ACTIVITY_DELTA for 'a1': no activity message has that id."],
                       transcript.warnings.map(&:message)
        end

        def test_a_snapshot_reconciles_by_id_in_place_and_drops_what_it_leaves_out
          transcript = replay([
                                { "type" => "TEXT_MESSAGE_START", "messageId" => "streamed" },
                                { "type" => "TEXT_MESSAGE_END", "messageId" => "streamed" },
                                { "type" => "REASONING_MESSAGE_START", "messageId" => "r1", "role" => "reasoning" },
                                { "type" => "REASONING_MESSAGE_END", "messageId" => "r1" },
                                { "type" => "TEXT_MESSAGE_START", "messageId" => "m1" },
                                { "type" => "TEXT_MESSAGE_CONTENT", "messageId" => "m1", "delta" => "draft" },
                                { "type" => "TEXT_MESSAGE_END", "messageId" => "m1" }
                              ])
          changed = transcript.apply({ "type" => "MESSAGES_SNAPSHOT", "messages" => [
                                       { "id" => "new", "role" => "assistant", "content" => "appended" },
                                       { "id" => "m1", "role" => "assistant", "content" => "final" }
                                     ] })

          assert_equal %w[r1 m1 new], transcript.messages.map(&:id),
                       "m1 keeps its place, new is appended, streamed is dropped, the reasoning stays"
          assert_equal "final", transcript.message("m1").parts.first[:text]
          assert_equal %w[new m1 streamed], changed, "the dropped id is reported so a relay can remove its row"

          transcript.apply({ "type" => "MESSAGES_SNAPSHOT", "messages" => [
                             { "id" => "r2", "role" => "reasoning", "content" => "restated" }
                           ] })

          assert_equal %w[r2], transcript.messages.map(&:id), "a snapshot carrying reasoning declares that set too"
        end

        def test_a_waiting_client_tool_keeps_waiting_through_a_snapshot
          start = { "type" => "TOOL_CALL_START", "toolCallId" => "c1", "toolCallName" => "poetry.tabs.set",
                    "parentMessageId" => "streamed" }
          transcript = replay([start, { "type" => "TOOL_CALL_END", "toolCallId" => "c1" }],
                              client_tools: ["poetry.tabs.set"])
          transcript.apply({ "type" => "MESSAGES_SNAPSHOT", "messages" => [
                             { "id" => "renamed", "role" => "assistant",
                               "toolCalls" => [{ "id" => "c1", "type" => "function",
                                                 "function" => { "name" => "poetry.tabs.set", "arguments" => "{}" } }] }
                           ] })

          assert_equal :awaiting_client, transcript.message("renamed").parts.first[:state]
          assert_equal "renamed", transcript.pending_client_tools.first[:message_id]
        end

        def test_a_chunk_continuing_a_call_from_a_snapshot_reopens_it
          snapshot = { "type" => "MESSAGES_SNAPSHOT", "messages" => [
            { "id" => "a1", "role" => "assistant",
              "toolCalls" => [{ "id" => "c1", "type" => "function",
                                "function" => { "name" => "f", "arguments" => "{\"a\":" } }] }
          ] }
          transcript = replay([snapshot, { "type" => "TOOL_CALL_CHUNK", "toolCallId" => "c1", "toolCallName" => "f",
                                           "delta" => "1}" }])

          assert_equal({ "a" => 1 }, transcript.message("a1").parts.first[:input])
        end

        def test_the_hosts_own_messages_join_the_conversation
          transcript = Transcript.new(client_tools: ["poetry.tabs.set"])
          transcript.add_message(RunInput.user_message("My name is Ada.", id: "u1"))
          start = { "type" => "TOOL_CALL_START", "toolCallId" => "c1", "toolCallName" => "poetry.tabs.set",
                    "parentMessageId" => "a1" }
          transcript.apply_all([{ "type" => "RUN_STARTED", "threadId" => "t", "runId" => "r" }, start,
                                { "type" => "TOOL_CALL_END", "toolCallId" => "c1" },
                                { "type" => "RUN_FINISHED", "threadId" => "t", "runId" => "r" }])

          assert_equal ["a1"], transcript.add_message(RunInput.tool_message("c1", "done", id: "t1"))
          assert_empty transcript.pending_client_tools
          assert_equal([%w[u1 user], %w[a1 assistant], %w[t1 tool]],
                       transcript.messages_for_input.map { |message| message.values_at("id", "role") })
        end

        def test_a_null_state_snapshot_applies
          transcript = Transcript.new
          transcript.apply({ "type" => "STATE_SNAPSHOT", "snapshot" => { "a" => 1 } })
          transcript.apply({ "type" => "STATE_SNAPSHOT", "snapshot" => nil })

          assert_nil transcript.state
        end

        def test_every_run_is_kept_and_a_cancelled_run_is_neither_success_nor_failure
          transcript = Transcript.new.apply_all([
                                                  { "type" => "RUN_STARTED", "threadId" => "t", "runId" => "r1" },
                                                  { "type" => "RUN_ERROR", "message" => "boom" },
                                                  { "type" => "RUN_STARTED", "threadId" => "t", "runId" => "r2" },
                                                  { "type" => "RUN_FINISHED", "threadId" => "t", "runId" => "r2",
                                                    "outcome" => { "type" => "cancelled" } }
                                                ])

          assert_equal(%i[error cancelled], transcript.runs.map { |run| run[:status] })
          assert_equal "boom", transcript.runs.first[:error][:message], "the first run's failure survives the second"
          assert_equal :cancelled, transcript.run[:status]
          assert_predicate transcript, :ended?
          assert_nil transcript.error

          opened = Transcript.new
          opened.apply({ "type" => "RUN_ERROR", "message" => "refused" })

          assert_equal 1, opened.runs.size, "a RUN_ERROR that opens the stream is a run of its own"
        end
      end
    end
  end
end
