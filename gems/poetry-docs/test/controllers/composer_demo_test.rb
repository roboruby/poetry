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
    %w[state ordering stop files keys].each { |anchor| assert_includes response.body, %(id="#{anchor}") }
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

  test "a message of files alone is accepted, and the reader's row names each file" do
    post "/components/composer/messages",
         params: { composer: "composer-files", message: "",
                   attachments: [ upload("sunset.png", "image/png", "12345"), upload("<b>plan.pdf", "application/pdf", "%PDF") ] }

    assert_response :success
    assert_includes response.body, 'action="append" target="composer-files-thread-messages"'
    assert_equal 2, response.body.scan('data-slot="attachment"').size
    assert_includes response.body, "sunset.png"
    assert_includes response.body, "5 Bytes"
    assert_includes response.body, "&lt;b&gt;plan.pdf"
    refute_includes response.body, "<b>plan"
    assert_match(/target="composer-files-action"><template><span id="composer-files-action"[^>]*data-running=""/,
                 response.body)
  end

  test "a message keeps to three files, and a param that is not an upload is no file" do
    files = %w[a b c d].map { |name| upload("#{name}.png", "image/png", "x") }
    post "/components/composer/messages", params: { composer: "composer-files", message: "four", attachments: files }

    assert_equal 3, response.body.scan('data-slot="attachment"').size

    post "/components/composer/messages", params: { composer: "composer-files", message: "", attachments: [ "a.png" ] }

    assert_response :unprocessable_entity
  end

  test "a request larger than the examples allow is refused before it is read" do
    post "/components/composer/messages",
         params: { composer: "composer-files", message: "big",
                   attachments: [ upload("big.bin", "application/octet-stream", "0" * 4.megabytes) ] }

    assert_response :content_too_large
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
    %w[attachments default disabled line_breaks running stopping tools].each do |name|
      get "/examples/components/composer/#{name}"

      assert_response :success, name
      assert_includes response.body, 'data-component="composer"', name
    end
  end

  test "the attachments example takes files in a multipart form with the paperclip leading the footer" do
    get "/examples/components/composer/attachments"

    assert_includes response.body, 'enctype="multipart/form-data"'
    assert_includes response.body, 'data-slot="composer-attach"'
    assert_includes response.body, 'accept="image/*,.pdf"'
    assert_includes response.body, 'data-poetry--core--file-drop-max-files-value="3"'
  end

  private

  def upload(name, type, body)
    file = Tempfile.new([ "composer-demo", File.extname(name) ])
    file.binmode
    file.write(body)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, type, true, original_filename: name)
  end
end
