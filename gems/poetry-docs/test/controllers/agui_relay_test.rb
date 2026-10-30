# frozen_string_literal: true

require "test_helper"

# The AG-UI relay demo: scripted AG-UI events relayed as versioned Turbo
# Streams over SSE, the frontend tool call handed to the browser, the
# interrupt answered as a URL decision, and the catalog endpoint.
class AguiRelayTest < ActionDispatch::IntegrationTest
  test "the demo page renders the tabs tool surface and the stream source" do
    get "/demos/agui-relay"

    assert_response :success
    assert_select "[data-poetry--agent--webmcp-name-value=sections]"
    assert_includes response.body, "Which plan fits a 10-person team"
    assert_includes response.body, "/demos/agui-relay/stream?"
  end

  test "run one streams versioned rows and ends by handing the tool call to the browser" do
    get "/demos/agui-relay/stream?s=1"

    assert_response :success
    versions = response.body.scan(/data-version="(\d+)"/).flatten.map(&:to_i)

    assert_equal versions.sort, versions
    assert_operator versions.length, :>, 5
    assert_includes response.body, 'action="append" target="agui-relay-scroller-messages"'
    assert_includes response.body, 'data-message-id="item-m1"'
    assert_includes response.body, 'action="vreplace" target="row-m1"'
    assert_includes response.body, 'data-slot="trace"'
    assert_includes response.body, "Thinking", "the reasoning shimmers while it streams"
    assert_includes response.body, "Thought"
    assert_includes response.body, "Looking up plans for 10 seats"
    assert_includes response.body, "Looked up plans for 10 seats"
    assert_includes response.body, "Team: $12 a seat, 5+ seats", "a finished call discloses its output"
    assert_includes response.body, 'data-status="pending"'
    assert_includes response.body, "waiting for you", "the tab tool asks the person first"
    assert_includes response.body, 'data-controller="poetry--agent--agui-client-tool"'
    assert_includes response.body, 'data-poetry--agent--agui-client-tool-confirm-value="true"'
    assert_includes response.body, "Switch to the pricing tab?"
    assert_includes response.body, 'data-action="poetry--agent--agui-client-tool#approve"'
    assert_includes response.body, 'data-action="poetry--agent--agui-client-tool#deny"'
    assert_includes response.body, "poetry.sections.set_value"
    assert_includes response.body, 'action="remove" target="agui-relay-source"'
  end

  test "a tool's app the page cannot show renders as a step with the result's text" do
    get "/demos/agui-relay/stream?s=1"

    assert_response :success
    assert_includes response.body, %(id="app-a1-0")
    assert_includes response.body, "app not shown"
    assert_includes response.body, "ui://poetry-docs/plans"
    assert_includes response.body, "Recommended for 10: Team."
    assert_operator response.body.scan("Looked up plans for 10 seats").size, :>=, 2
  end

  test "continue resolves the client tool and points at the next run" do
    post "/demos/agui-relay/continue?s=1", params: { toolCallId: "c-tab", name: "poetry.sections.set_value",
                                                     content: '{"value":"pricing","changed":true}' }.to_json,
                                          headers: { "Content-Type" => "application/json" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, 'action="vreplace" target="row-m1"'
    assert_includes response.body, "Switched to the pricing tab"
    assert_includes response.body, "/demos/agui-relay/stream?"
    assert_includes response.body, "s=2"
  end

  test "continue answers a declined tool call as declined, never as run" do
    post "/demos/agui-relay/continue?s=1", params: { toolCallId: "c-tab", name: "poetry.sections.set_value",
                                                     declined: true }.to_json,
                                          headers: { "Content-Type" => "application/json" }

    assert_response :success
    assert_includes response.body, "Denied: Switching to the pricing tab"
    refute_includes response.body, "Switched to the pricing tab"
    assert_includes response.body, "tool_result=declined"
  end

  test "run two pauses on the interrupt and run three follows the decision" do
    get "/demos/agui-relay/stream?s=2"

    assert_includes response.body, "Start a 30-day Team trial"
    assert_includes response.body, 'data-slot="item"', "the interrupt asks as an approval prompt"
    assert_includes response.body, "Approve"
    refute_includes response.body, "TR-3041", "the continuation must not leak into the paused stream"

    get "/demos/agui-relay/stream?s=3&d=1"

    assert_includes response.body, "TR-3041"
    assert_includes response.body, "Started a 30-day Team trial"
    assert_includes response.body, "Ran the billing subagent", "the subagent's call nests under a step naming it"
    assert_includes response.body, 'id="subagent-m3-billing"'
    assert_includes response.body, "Replay from the top"
    assert_includes response.body, 'action="vreplace" target="row-m3" method="morph"'
    assert_includes response.body, 'id="a2ui-trial"'
    assert_includes response.body, "/demos/agui-relay/surface"
    assert_includes response.body, 'name="a2ui[values][/email]"'
    assert_includes response.body, "data-controller=\"poetry--agent--a2ui-surface\""

    get "/demos/agui-relay/stream?s=3&d=0"

    assert_includes response.body, "No trial started"
  end

  test "the trial surface's action feeds run four as forwardedProps" do
    post "/demos/agui-relay/surface", params: { a2ui: { surface: "trial", action: "remind", values: { "/email" => "nope" } } }

    assert_response :unprocessable_entity
    assert_includes response.body, 'action="vreplace" target="row-a3" method="morph"'
    assert_includes response.body, "Enter a valid email"

    post "/demos/agui-relay/surface", params: { a2ui: { surface: "trial", action: "remind", values: { "/email" => "ada@roboruby.com" } } }

    assert_response :success
    assert_includes response.body, 'action="remove" target="agui-relay-source"'
    assert_includes response.body, "s=4"
    assert_includes response.body, "email=ada%40roboruby.com"

    get "/demos/agui-relay/stream?s=4&email=ada%40roboruby.com"

    assert_includes response.body, "Reminder set for ada@roboruby.com"
    assert_includes response.body, "forwardedProps.a2uiAction"
    assert_includes response.body, "Replay from the top"
  end

  test "the standalone example builds its own history" do
    get "/examples/demos/agui-relay/default?s=3&d=1&tool_result=declined"

    assert_response :success
    assert_includes response.body, "Denied: Switching to the pricing tab", "a declined tab switch stays declined"
  end

  test "the states example renders the rows the scripted run does not reach" do
    get "/examples/demos/agui-relay/states"

    assert_response :success
    assert_includes response.body, "roster.csv", "a user turn's document is an attachment"
    assert_includes response.body, "Ten seats across four rows.", "a result's text is its output"
    assert_includes response.body, 'src="data:image/svg+xml;base64,', "a result's image renders as a picture"
    assert_includes response.body, "Denied: Switching to the pricing tab"
    assert_includes response.body, "The research subagent failed"
    assert_includes response.body, "Stopped: Looking up plans for 10 seats"
    assert_includes response.body, "The agent stopped this response"
    assert_includes response.body, "The stream stopped before the response finished"
  end

  test "the scripted agent is a conformant AG-UI 1.0 producer" do
    runs = [ [ 1, nil ], [ 2, nil ], [ 3, true ], [ 3, false ], [ 4, nil ] ].map do |index, decision|
      Poetry::Docs::AguiReplay.events(index, decision: decision, email: "ada@roboruby.com").map { |event| event.except("_sleep") }
    end
    events = runs.flatten
    kinds = events.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |event, ids|
      kind = { "TEXT_MESSAGE_START" => :text, "REASONING_MESSAGE_START" => :reasoning,
               "TOOL_CALL_RESULT" => :tool, "ACTIVITY_SNAPSHOT" => :activity }[event["type"]]
      ids[event["messageId"]] << kind if kind
    end

    runs.each { |run| assert_equal "1.0", run.find { |event| event["type"] == "RUN_STARTED" }["protocolVersion"] }
    events.select { |event| event["type"] == "REASONING_MESSAGE_START" }.each { |event| assert_equal "reasoning", event["role"] }
    kinds.each { |id, list| assert_equal 1, list.uniq.size, "message id #{id} names #{list.uniq.join(" and ")} messages" }
    assert_empty events.map { |event| event["type"] } - Poetry::Agent::AGUI::EVENT_TYPES.grep_v(/\ATHINKING_/)
  end

  test "the A2UI catalog is served as JSON" do
    get "/a2ui/catalog.json"

    assert_response :success
    assert_equal "application/json", response.media_type
    catalog = JSON.parse(response.body)

    assert_equal Poetry::Agent::A2UI::Catalog::DEFAULT_ID, catalog["catalogId"]
    assert_operator catalog["components"].size, :>, 70
    assert_equal "Tabs", catalog.dig("components", "Tabs", "properties", "component", "const")
  end

  test "the A2UI catalog is served in both versions" do
    get "/a2ui/v1_0/catalog.json"

    assert_equal Poetry::Agent::A2UI::Catalog::DEFAULT_ID, JSON.parse(response.body)["catalogId"]
    get "/a2ui/v0_9/catalog.json"

    assert_response :success
    legacy = JSON.parse(response.body)

    assert_equal Poetry::Agent::A2UI::Catalog::V0_9_ID, legacy["catalogId"]
    assert_equal "formatNumber", legacy.dig("functions", "formatNumber", "properties", "call", "const")
  end
end
