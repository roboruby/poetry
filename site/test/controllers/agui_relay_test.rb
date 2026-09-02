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
    assert_includes response.body, "lookup_plans"
    assert_includes response.body, "in the browser"
    assert_includes response.body, 'data-controller="poetry--agent--agui-client-tool"'
    assert_includes response.body, "poetry.sections.set_value"
    assert_includes response.body, 'action="remove" target="agui-relay-source"'
  end

  test "continue resolves the client tool and points at the next run" do
    post "/demos/agui-relay/continue?s=1", params: { toolCallId: "c-tab", name: "poetry.sections.set_value",
                                                     content: '{"value":"pricing","changed":true}' }.to_json,
                                          headers: { "Content-Type" => "application/json" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, 'action="vreplace" target="row-m1"'
    assert_includes response.body, "done"
    assert_includes response.body, "/demos/agui-relay/stream?"
    assert_includes response.body, "s=2"
  end

  test "run two pauses on the interrupt and run three follows the decision" do
    get "/demos/agui-relay/stream?s=2"

    assert_includes response.body, "Start a 30-day Team trial"
    assert_includes response.body, "Approve"
    refute_includes response.body, "TR-3041", "the continuation must not leak into the paused stream"

    get "/demos/agui-relay/stream?s=3&d=1"

    assert_includes response.body, "TR-3041"
    assert_includes response.body, "Replay from the top"

    get "/demos/agui-relay/stream?s=3&d=0"

    assert_includes response.body, "No trial started"
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
end
