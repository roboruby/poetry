# frozen_string_literal: true

require "test_helper"

# The chat replay rig: scripted Poetry::Ui::Chat frames streamed as
# versioned Turbo Streams over SSE, state addressed entirely by URL.
class ChatReplayTest < ActionDispatch::IntegrationTest
  test "the demo page renders completed turns and the pending streaming row" do
    get "/demos/chat-replay"

    assert_response :success
    assert_includes response.body, "What&#39;s the weather looking like in Tokyo"
    assert_includes response.body, 'id="row-chat-msg-2" data-version="0"'
    assert_includes response.body, "turbo-stream-source"
    assert_includes response.body, "/demos/chat-replay/stream?"
  end

  test "the stream is versioned, ordered, and ends by removing its source" do
    get "/demos/chat-replay/stream?s=1"

    assert_response :success
    versions = response.body.scan(/data-version="(\d+)"/).flatten.map(&:to_i)

    assert_equal versions.sort, versions
    assert_operator versions.length, :>, 3
    assert_includes response.body, 'action="vreplace" target="row-chat-msg-2"'
    assert_includes response.body, 'action="remove" target="chat-replay-source"'
    assert_includes response.body, "Send:"
  end

  test "the approval turn pauses and offers the decision" do
    get "/demos/chat-replay/stream?s=3"

    assert_includes response.body, "awaiting approval"
    assert_includes response.body, "Approve"
    assert_includes response.body, "/demos/chat-replay?a=1&amp;s=3"
    refute_includes response.body, "RT-204", "the continuation must not leak into the paused stream"
  end

  test "continuations resolve per decision" do
    get "/demos/chat-replay/stream?s=3&a=1"

    assert_includes response.body, "RT-204"
    assert_includes response.body, "Replay from the top"

    get "/demos/chat-replay/stream?s=3&a=0"

    assert_includes response.body, "denied"
    refute_includes response.body, "RT-204"
  end

  test "streams replay byte-identical" do
    get "/demos/chat-replay/stream?s=1"
    first = response.body
    get "/demos/chat-replay/stream?s=1"

    assert_equal first, response.body
  end

  test "the stream's control links target the consuming page, allowlisted" do
    get "/demos/chat-replay/stream?s=3&page=/examples/demos/chat-replay/default"

    assert_includes response.body, "/examples/demos/chat-replay/default?a=1"

    get "/demos/chat-replay/stream?s=3&page=https://evil.example/phish"

    assert_includes response.body, "/demos/chat-replay?a=1", "unknown pages fall back to the demo page"
  end

  test "the standalone example works with the same machinery" do
    get "/examples/demos/chat-replay/default?s=3&a=1"

    assert_response :success
    assert_includes response.body, "awaiting approval"
  end
end
