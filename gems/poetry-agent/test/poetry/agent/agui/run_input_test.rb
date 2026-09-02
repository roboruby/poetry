# frozen_string_literal: true

require "test_helper"

module Poetry
  module Agent
    module AGUI
      class RunInputTest < Minitest::Test
        def test_builds_the_camel_cased_wire_hash
          input = RunInput.build(thread_id: "t1", run_id: "r1", messages: [RunInput.user_message("hi", id: "u1")],
                                 tools: [{ "name" => "x" }], state: { "a" => 1 }, parent_run_id: "r0",
                                 resume: [RunInput.resume_entry("i1", status: "approved", payload: { "ok" => true })])

          assert_equal %w[threadId runId state messages tools context forwardedProps parentRunId resume], input.keys
          assert_equal({ "id" => "u1", "role" => "user", "content" => "hi" }, input["messages"].first)
          assert_equal({ "interruptId" => "i1", "status" => "approved", "payload" => { "ok" => true } },
                       input["resume"].first)
          assert_match(/\A[0-9a-f-]{36}\z/, RunInput.build(thread_id: "t", messages: [])["runId"])
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
