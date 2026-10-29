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
          Relay.new(transcript: transcript, render: render, container: container).tap { |relay| open_run(relay) }
        end

        # A conformant stream begins with RUN_STARTED.
        def open_run(relay)
          relay.apply({ "type" => "RUN_STARTED", "threadId" => "t", "runId" => "r" })
          relay
        end

        def test_first_appearance_appends_then_versioned_replaces
          relay = relay()
          first = relay.apply({ "type" => "TEXT_MESSAGE_START", "messageId" => "m1", "role" => "assistant" })
          second = relay.apply({ "type" => "TEXT_MESSAGE_CONTENT", "messageId" => "m1", "delta" => "hi" })
          none = relay.apply({ "type" => "STATE_SNAPSHOT", "snapshot" => {} })

          assert_equal 1, first.size
          assert_match(/\A<turbo-stream action="append" target="chat"><template><div id="row-m1" data-version="2">/,
                       first.first)
          assert_match(/\A<turbo-stream action="vreplace" target="row-m1"><template>/, second.first)
          assert_includes second.first, %(<div id="row-m1" data-version="3">hi</div>)
          assert_empty none
        end

        def test_first_appearance_uses_the_append_renderer
          transcript = Transcript.new
          row = ->(message, version) { %(<div id="row-#{message.id}" data-version="#{version}"></div>) }
          item = ->(message, version) { %(<li id="item-#{message.id}">#{row.call(message, version)}</li>) }
          relay = Relay.new(transcript: transcript, container: "chat", render: row, append_render: item)
          open_run(relay)
          first = relay.apply({ "type" => "TEXT_MESSAGE_START", "messageId" => "m1", "role" => "assistant" })
          second = relay.apply({ "type" => "TEXT_MESSAGE_CONTENT", "messageId" => "m1", "delta" => "x" })

          assert_includes first.first, %(<template><li id="item-m1">)
          assert_includes second.first, %(<template><div id="row-m1")
        end

        def test_a_rejected_push_still_applies_what_preceded_the_failure
          transcript = Transcript.new
          relay = open_run(Relay.new(transcript: transcript, render: ->(*) { "" }))
          relay.apply({ "type" => "TEXT_MESSAGE_CHUNK", "messageId" => "m", "delta" => "a" })
          assert_raises(ProtocolError) { relay.apply({ "type" => "RUN_STARTED", "threadId" => "t", "runId" => "r2" }) }

          assert_equal :done, transcript.message("m").parts.first[:state]
          assert_raises(ProtocolError) { relay.apply({ "type" => "RUN_FINISHED", "threadId" => "t", "runId" => "r" }) }
          assert_equal 1, transcript.message("m").parts.size
        end

        def test_without_a_pipeline_the_relay_takes_events_as_verified
          relay = Relay.new(transcript: Transcript.new, render: ->(*) { "" }, pipeline: nil)

          assert_nil relay.pipeline
          assert_empty relay.finish
          assert_raises(ArgumentError) { relay.apply({ "type" => "TEXT_MESSAGE_CHUNK", "messageId" => "m" }) }
        end

        def test_a_row_a_snapshot_drops_comes_off_the_page_once
          relay = relay()
          relay.apply({ "type" => "TEXT_MESSAGE_START", "messageId" => "streamed", "role" => "assistant" })
          streams = relay.apply({ "type" => "MESSAGES_SNAPSHOT",
                                  "messages" => [{ "id" => "renamed", "role" => "assistant", "content" => "hi" }] })

          assert_match(/\A<turbo-stream action="append" target="chat"><template><div id="row-renamed"/, streams.first)
          assert_equal %(<turbo-stream action="remove" target="row-streamed"></turbo-stream>), streams.last
          assert_empty relay.apply({ "type" => "MESSAGES_SNAPSHOT", "messages" => [] }).grep(/row-streamed/)

          wrapped = Relay.new(transcript: Transcript.new, container: "chat", render: ->(*) { "" },
                              remove_targets: ->(id) { %([data-message-id="item-#{id}"]) })
          open_run(wrapped)
          wrapped.apply({ "type" => "TEXT_MESSAGE_START", "messageId" => "m1", "role" => "assistant" })

          removal = %(<turbo-stream action="remove" targets="[data-message-id=&quot;item-m1&quot;]"></turbo-stream>)

          assert_equal [removal], wrapped.apply({ "type" => "MESSAGES_SNAPSHOT", "messages" => [] })
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

        def test_a_tool_that_asks_first_waits_inside_the_hosts_approval_prompt
          transcript = Transcript.new(client_tools: [{ name: "book", confirm: true }])
          relay = open_run(Relay.new(transcript: transcript, render: ->(message, _) { message.id }, container: "chat"))
          relay.apply({ "type" => "TOOL_CALL_START", "toolCallId" => "c1", "toolCallName" => "book" })
          relay.apply({ "type" => "TOOL_CALL_END", "toolCallId" => "c1" })

          assert_raises(ArgumentError) { relay.client_tool_streams(continue_url: "/go") }
          prompt = lambda { |pending|
            %(<button data-action="poetry--agent--agui-client-tool#approve">#{pending[:name]}</button>)
          }
          stream = relay.client_tool_streams(continue_url: "/go", approval: prompt).first

          assert_includes stream, %(data-poetry--agent--agui-client-tool-confirm-value="true")
          assert_includes stream, %(#approve">book</button>)
          refute_includes stream, " hidden", "the prompt is shown"
        end

        def test_finish_truncates_a_run_the_stream_broke_off_in
          broken = relay
          broken.apply({ "type" => "TEXT_MESSAGE_START", "messageId" => "m1", "role" => "assistant" })
          streams = broken.finish

          assert_predicate broken.transcript, :truncated?
          assert_equal 1, streams.size, "the open message re-renders, closed"
          finished = relay
          finished.apply({ "type" => "RUN_FINISHED", "threadId" => "t", "runId" => "r" })

          assert_empty finished.finish
          assert_empty Relay.new(transcript: Transcript.new, render: ->(*) { "" }, pipeline: nil).finish
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
