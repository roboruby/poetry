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
    %w[state ordering stop files mentions server-fed-menus suggested-prompts keys].each do |anchor|
      assert_includes response.body, %(id="#{anchor}")
    end
  end

  test "the page's server-fed example names the people endpoint and renders no person" do
    get "/components/composer"

    menu = Nokogiri::HTML5(response.body).at_css("#composer-people [data-slot=composer-menu]")
    list = menu.at_css("[role=listbox]")

    assert_equal "/components/composer/people", menu["data-src"]
    assert_equal "q", menu["data-param"]
    assert_equal "turbo-frame", list.name
    assert_empty list.element_children
  end

  def people(word, frame: "composer-people-menu-0")
    get "/components/composer/people", params: { q: word }, headers: { "Turbo-Frame" => frame }

    assert_response :success
    Nokogiri::HTML5.fragment(response.body)
  end

  test "the people endpoint answers in the frame that asked, with no layout around it" do
    answer = people("ro")
    frame = answer.at_css("turbo-frame")

    assert_equal "composer-people-menu-0", frame["id"]
    assert_equal [ frame ], answer.element_children.to_a, "the frame is the whole answer"
    assert_equal %w[composer-people-menu-0-option-0 composer-people-menu-0-option-1],
                 frame.css("[role=option]").first(2).pluck("id")
    assert(frame.css("[role=option]").all? { |option| option.at_css("svg") })
  end

  test "names that start with the word come first, then names and teams that hold it" do
    labels = people("ro").css("[role=option]").pluck("data-label")

    assert_equal [ "Rosa Park", "Rob Lin", "Robin Vale" ], labels.first(3)
    assert_includes labels, "Omar Farouk", "a name that holds the word follows"
    assert_equal %w[rosa rob robin], people("ro").css("[role=option]").first(3).pluck("data-value")
  end

  test "a team matches, though the page never holds one" do
    design = people("design").css("[role=option]")

    assert_predicate design, :any?
    assert(design.all? { |option| option.at_css("[data-slot=composer-menu-option-description]").text == "Design" })
    assert(design.none? { |option| option["data-label"].downcase.include?("design") })
  end

  test "an answer holds eight rows at most, and none for a word nobody answers to" do
    assert_equal 8, people("").css("[role=option]").size
    assert_equal 8, people("a").css("[role=option]").size
    assert_empty people("zzzz").css("[role=option]")
    assert_equal "composer-people-menu-0", people("zzzz").at_css("turbo-frame")["id"]
  end

  test "the word is the reader's: markup in it matches nobody and is never echoed" do
    answer = people("<script>alert(1)</script>")

    assert_empty answer.css("[role=option]")
    refute_includes response.body, "<script>"
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

  test "the values a chip menu posted come back as chips, and are not a message on their own" do
    post "/components/composer/messages",
         params: { composer: "composer-menus", message: "compare @ana", context: [ "q3-plan", "<b>roadmap" ] }

    assert_response :success
    assert_includes response.body, "compare @ana"
    assert_equal 2, response.body.scan('data-slot="attachment"').size
    assert_includes response.body, "q3-plan"
    assert_includes response.body, "&lt;b&gt;roadmap"

    post "/components/composer/messages", params: { composer: "composer-menus", message: "", context: [ "q3-plan" ] }

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
    %w[attachments default disabled line_breaks menus running stopping tools].each do |name|
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

  test "the menus example renders three closed menus over a native textarea" do
    get "/examples/components/composer/menus"

    assert_equal 3, response.body.scan('data-slot="composer-menu"').size
    assert_includes response.body, 'aria-controls="composer-menus-menu-0 composer-menus-menu-1 composer-menus-menu-2"'
    assert_includes response.body, 'aria-autocomplete="list"'
    assert_includes response.body, 'data-insert="/summarize "'
    assert_includes response.body, 'data-name="context[]"'
    refute_includes response.body, "aria-expanded"
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
