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
            { "type" => "TOOL_CALL_START", "toolCallId" => "c2", "toolCallName" => "poetry.sections.set_value" },
            { "type" => "TOOL_CALL_ARGS", "toolCallId" => "c2", "delta" => "{\"value\":\"pricing\"}" },
            { "type" => "TOOL_CALL_END", "toolCallId" => "c2" },
            { "type" => "RUN_FINISHED", "threadId" => "t1", "runId" => "r1" }
          ]
        end

        def test_folds_a_run_into_parts_state_and_pending_client_tools
          transcript = Transcript.new(client_tools: ["poetry.sections.set_value"]).apply_all(scripted_run)
          message = transcript.message("m1")

          assert_equal(%i[reasoning text tool tool], message.parts.map { |part| part[:kind] })
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
          transcript = Transcript.new
          transcript.apply({ "type" => "RUN_STARTED", "threadId" => "t", "runId" => "r" })
          transcript.apply({ "type" => "TEXT_MESSAGE_CHUNK", "messageId" => "m9", "delta" => "chunked" })
          transcript.apply({ "type" => "TOOL_CALL_CHUNK", "toolCallId" => "c9", "toolCallName" => "book",
                             "delta" => "{\"a\":1}" })
          transcript.apply({ "type" => "ACTIVITY_SNAPSHOT", "messageId" => "act", "activityType" => "PLAN",
                             "content" => { "steps" => [] } })
          transcript.apply({ "type" => "ACTIVITY_DELTA", "messageId" => "act", "activityType" => "PLAN",
                             "patch" => [{ "op" => "add", "path" => "/steps/-", "value" => "one" }] })
          transcript.apply({ "type" => "CUSTOM", "name" => "ping", "value" => 1 })
          transcript.apply({ "type" => "NOT_A_THING" })
          transcript.apply({ "type" => "RUN_FINISHED", "threadId" => "t", "runId" => "r",
                             "outcome" => { "type" => "interrupt",
                                            "interrupts" => [{ "id" => "i1", "reason" => "approval",
                                                               "message" => "Book it?" }] } })

          assert_equal "chunked", transcript.message("m9").parts[0][:text]
          assert_equal({ "a" => 1 }, transcript.message("m9").parts[1][:input])
          assert_equal({ "steps" => ["one"] }, transcript.activities["act"]["content"])
          assert_equal :activity, transcript.message("act").parts.first[:kind]
          assert_equal ["NOT_A_THING"], transcript.unknown_events
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
        end
      end
    end
  end
end
