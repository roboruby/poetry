# frozen_string_literal: true

require "test_helper"

# The Composer page's live examples: the server half of the composer's
# contract with a scripted reply. A message draws Stop and hands the page
# a stream source; the stream writes the reply and draws Send; Stop
# removes the source and draws Send.
class ComposerDemoTest < ActionDispatch::IntegrationTest
  test "the page renders the composer and its contract sections" do
    get "/components/composer"

    assert_response :success
    assert_includes response.body, 'data-component="composer"'
    assert_includes response.body, 'id="composer-demo-action"'
    assert_includes response.body, "/components/composer/messages?composer=composer-demo"
    assert_includes response.body, "/components/composer/stop?composer=composer-demo"
    %w[state ordering stop keys].each { |anchor| assert_includes response.body, %(id="#{anchor}") }
  end

  test "a message draws Stop, appends both rows and hands the page the reply's source" do
    post "/components/composer/messages", params: { composer: "composer-demo", message: "Hello <b>there</b>" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    reply = response.body[/composer-demo-reply-\h{8}/]

    assert reply, "the reply's row has an id of its own"
    assert_includes response.body, 'action="append" target="composer-demo-thread-messages"'
    assert_includes response.body, "Hello &lt;b&gt;there&lt;/b&gt;", "the reader's text is escaped"
    assert_includes response.body, %(id="#{reply}")
    assert_includes response.body, 'action="append" target="composer-demo"'
    assert_includes response.body, %(<turbo-stream-source id="composer-demo-source")
    assert_includes response.body, "/components/composer/reply?composer=composer-demo&amp;reply=#{reply}"
    assert_match(/action="vreplace" target="composer-demo-action"><template><span id="composer-demo-action"[^>]*data-version="\d+"[^>]*data-running=""/,
                 response.body)
    assert_includes response.body, 'form="composer-demo-stop"'
  end

  test "a blank message is refused, so the field keeps its text" do
    post "/components/composer/messages", params: { composer: "composer-demo", message: "   " }

    assert_response :unprocessable_entity
  end

  test "the reply streams as versioned frames of its row and ends by drawing Send" do
    get "/components/composer/reply?composer=composer-demo&reply=composer-demo-reply-0a1b2c3d"

    assert_response :success
    frames = response.body.scan(/action="vreplace" target="composer-demo-reply-0a1b2c3d"><template><div[^>]*data-version="(\d+)"/)
                     .flatten.map(&:to_i)

    assert_operator frames.length, :>, 5
    assert_equal frames.sort, frames
    assert_equal frames.uniq, frames
    assert_includes response.body, "whichever comes first.", "the last frame holds the whole reply"

    closing = response.body.split("\n\n").reject(&:blank?).last

    assert_includes closing, 'action="remove" target="composer-demo-source"'
    assert_match(/action="vreplace" target="composer-demo-action"><template><span id="composer-demo-action"/, closing)
    refute_includes closing, "data-running", "the slot is drawn idle"
    assert_includes closing, 'data-slot="composer-send"'
  end

  test "Stop removes the source, marks the transcript and draws Send" do
    post "/components/composer/stop", params: { composer: "composer-demo" }

    assert_response :success
    assert_includes response.body, 'action="remove" target="composer-demo-source"'
    assert_includes response.body, "Stopped"
    assert_match(/action="vreplace" target="composer-demo-action"><template><span id="composer-demo-action"/, response.body)
    assert_includes response.body, 'data-slot="composer-send"'
    refute_includes response.body, "data-running"
  end

  test "the composer's id comes from the address and nothing else does" do
    post "/components/composer/stop", params: { composer: "composer-tools" }

    assert_includes response.body, 'target="composer-tools-action"'

    post "/components/composer/stop", params: { composer: 'x"><script>' }

    assert_includes response.body, 'target="composer-demo-action"', "an id that is not one falls back"
    refute_includes response.body, "<script>"
  end

  test "every example renders standalone" do
    %w[default disabled line_breaks running stopping tools].each do |name|
      get "/examples/components/composer/#{name}"

      assert_response :success, name
      assert_includes response.body, 'data-component="composer"', name
    end
  end
end
