# frozen_string_literal: true

require "test_helper"

module Poetry
  module Agent
    module AGUI
      class SSETest < Minitest::Test
        def test_parses_events_across_chunks_comments_and_crlf
          parser = SSE::Parser.new
          seen = []
          collect = ->(event) { seen << event }
          parser.feed(": keep-alive\r\nevent: message\r\ndata: {\"type\":\"RUN_STA", &collect)
          parser.feed("RTED\",\"runId\":\"r1\"}\r\n\r\nid: 7\ndata: {\"type\":\"TEXT_MESSAGE_CONTENT\",\n",
                      &collect)
          parser.feed("data: \"delta\":\"hi\"}\n\n", &collect)
          parser.finish(&collect)

          assert_equal(%w[RUN_STARTED TEXT_MESSAGE_CONTENT], seen.map { |event| event["type"] })
          assert_equal "hi", seen.last["delta"]
        end

        def test_trailing_event_without_blank_line_and_bad_json
          events = SSE.parse("data: {\"type\":\"RUN_FINISHED\"}\ndata: not json\n\ndata: {\"type\":\"RAW\"}")

          assert_equal(%w[RAW], events.map { |event| event["type"] })
          parser = SSE::Parser.new

          parser.feed("data: {oops}\n\n") { |_event| flunk("unreadable data must not yield") }

          assert_equal ["{oops}"], parser.errors
        end

        def test_parses_an_enumerable_of_chunks
          chunks = ["data: {\"type\":\"CUSTOM\",\"name\":\"x\"}\n", "\n"]

          assert_equal [{ "type" => "CUSTOM", "name" => "x" }], SSE.parse(chunks)
        end
      end
    end
  end
end
