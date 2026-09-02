# frozen_string_literal: true

require "test_helper"

module Poetry
  module Agent
    module AGUI
      class RelayTest < Minitest::Test
        def relay(container: "chat")
          transcript = Transcript.new(client_tools: ["poetry.sections.set_value"])
          render = lambda { |message, version|
            %(<div id="row-#{message.id}" data-version="#{version}">#{message.parts.map do |p|
              p[:text] || p[:name]
            end.join("|")}</div>)
          }
          Relay.new(transcript: transcript, render: render, container: container)
        end

        def test_first_appearance_appends_then_versioned_replaces
          relay = relay()
          first = relay.apply({ "type" => "TEXT_MESSAGE_START", "messageId" => "m1", "role" => "assistant" })
          second = relay.apply({ "type" => "TEXT_MESSAGE_CONTENT", "messageId" => "m1", "delta" => "hi" })
          none = relay.apply({ "type" => "STATE_SNAPSHOT", "snapshot" => {} })

          assert_equal 1, first.size
          assert_match(/\A<turbo-stream action="append" target="chat"><template><div id="row-m1" data-version="1">/,
                       first.first)
          assert_match(/\A<turbo-stream action="vreplace" target="row-m1"><template>/, second.first)
          assert_includes second.first, %(<div id="row-m1" data-version="2">hi</div>)
          assert_empty none
        end

        def test_first_appearance_uses_the_append_renderer
          transcript = Transcript.new
          row = ->(message, version) { %(<div id="row-#{message.id}" data-version="#{version}"></div>) }
          item = ->(message, version) { %(<li id="item-#{message.id}">#{row.call(message, version)}</li>) }
          relay = Relay.new(transcript: transcript, container: "chat", render: row, append_render: item)
          first = relay.apply({ "type" => "TEXT_MESSAGE_START", "messageId" => "m1", "role" => "assistant" })
          second = relay.apply({ "type" => "TEXT_MESSAGE_CONTENT", "messageId" => "m1", "delta" => "x" })

          assert_includes first.first, %(<template><li id="item-m1">)
          assert_includes second.first, %(<template><div id="row-m1")
        end

        def test_marked_messages_update_instead_of_appending
          relay = relay()
          relay.mark_seen("m1")
          streams = relay.apply({ "type" => "TEXT_MESSAGE_START", "messageId" => "m1", "role" => "assistant" })

          assert_match(/action="vreplace" target="row-m1"/, streams.first)
        end

        def test_without_a_container_every_change_is_a_replace
          relay = relay(container: nil)
          streams = relay.apply({ "type" => "TEXT_MESSAGE_START", "messageId" => "m1", "role" => "assistant" })

          assert_match(/action="vreplace" target="row-m1"/, streams.first)
        end

        def test_client_tool_streams_carry_the_bridge_element
          relay = relay()
          relay.apply({ "type" => "TOOL_CALL_START", "toolCallId" => "c1",
                        "toolCallName" => "poetry.sections.set_value" })
          relay.apply({ "type" => "TOOL_CALL_ARGS", "toolCallId" => "c1", "delta" => "{\"value\":\"pricing\"}" })
          relay.apply({ "type" => "TOOL_CALL_END", "toolCallId" => "c1" })
          streams = relay.client_tool_streams(continue_url: "/agent/continue?s=1&x=<y>")

          assert_equal 1, streams.size
          assert_match(/action="append" target="chat"/, streams.first)
          assert_includes streams.first, %(data-controller="poetry--agent--agui-client-tool")
          assert_includes streams.first,
                          %(data-poetry--agent--agui-client-tool-url-value="/agent/continue?s=1&amp;x=&lt;y&gt;")
          call = JSON.parse(CGI.unescapeHTML(streams.first[/call-value="([^"]*)"/, 1]))

          assert_equal(
            { "toolCallId" => "c1", "name" => "poetry.sections.set_value", "args" => { "value" => "pricing" } }, call
          )
        end

        def test_turbo_stream_builders_and_sse_framing
          assert_equal %(<turbo-stream action="remove" target="x"></turbo-stream>), TurboStream.remove("x")
          assert_equal "data: <a>b c</a>\n\n", TurboStream.sse("<a>b\nc</a>")
          assert_equal %(<turbo-stream action="replace" target="a&quot;b"><template><i></i></template></turbo-stream>),
                       TurboStream.replace(%(a"b), "<i></i>")
        end
      end
    end
  end
end
