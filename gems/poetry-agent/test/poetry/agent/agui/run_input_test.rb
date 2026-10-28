# frozen_string_literal: true

require "test_helper"

module Poetry
  module Agent
    module AGUI
      class RunInputTest < Minitest::Test
        def test_builds_the_camel_cased_wire_hash
          input = RunInput.build(thread_id: "t1", run_id: "r1", messages: [RunInput.user_message("hi", id: "u1")],
                                 tools: [{ "name" => "x" }], state: { "a" => 1 }, parent_run_id: "r0",
                                 resume: [RunInput.resume_entry("i1", status: "resolved", payload: { "ok" => true })])

          keys = %w[threadId runId protocolVersion state messages tools context forwardedProps parentRunId resume]

          assert_equal keys, input.keys
          assert_equal "1.0", input["protocolVersion"]
          assert_equal({ "id" => "u1", "role" => "user", "content" => "hi" }, input["messages"].first)
          assert_equal({ "interruptId" => "i1", "status" => "resolved", "payload" => { "ok" => true } },
                       input["resume"].first)
          assert_match(/\A[0-9a-f-]{36}\z/, RunInput.build(thread_id: "t", messages: [])["runId"])
        end

        def test_the_version_declaration_can_be_omitted_for_an_older_agent
          refute RunInput.build(thread_id: "t", messages: [], protocol_version: nil).key?("protocolVersion")
        end

        def test_resume_entries_take_only_the_statuses_ag_ui_defines
          assert_equal({ "interruptId" => "i1", "status" => "cancelled" },
                       RunInput.resume_entry("i1", status: "cancelled"))
          error = assert_raises(ArgumentError) { RunInput.resume_entry("i1", status: "approved") }

          assert_includes error.message, "resolved, cancelled"
          assert_raises(ArgumentError) { RunInput.resume_entry("i1") }
        end

        def test_messages_keep_content_parts_and_send_data_as_json
          parts = [{ "type" => "text", "text" => "What is this?" },
                   { "type" => "image", "source" => { "type" => "url", "value" => "https://example.com/a.png" } }]

          assert_equal parts, RunInput.user_message(parts, id: "u1")["content"]
          assert_equal parts, RunInput.tool_message("c1", parts, id: "t1")["content"]
          assert_equal "{\"ok\":true}", RunInput.tool_message("c1", { "ok" => true }, id: "t1")["content"]
        end

        def test_tool_message_and_descriptor
          message = RunInput.tool_message("c1", "done", error: "boom", id: "m1")

          assert_equal(
            { "id" => "m1", "role" => "tool", "content" => "done", "toolCallId" => "c1", "error" => "boom" }, message
          )
          definition = { "name" => "set_value", "description" => "Activate.", "inputSchema" => { "type" => "object" } }

          assert_equal({ "name" => "poetry.sections.set_value", "description" => "Activate.",
                         "parameters" => { "type" => "object" } }, AGUI.tool_descriptor("sections", definition))
          assert_equal({ "type" => "object", "properties" => {} },
                       AGUI.tool_descriptor("d", { "name" => "open", "description" => "Open." })["parameters"])
        end
      end
    end
  end
end
