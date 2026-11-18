require "test_helper"

# The Markdown page and its live example: the Composer page's scripted
# reply, asked for in Markdown. Every frame of the stream is the reply's
# row rendered again with the text so far.
class MarkdownDemoTest < ActionDispatch::IntegrationTest
  REPLY = "markdown-demo-reply-0a1b2c3d".freeze

  # The stream's frames of the reply's row, in order: each the row's HTML.
  def frames
    get "/components/composer/reply?composer=markdown-demo&reply=#{REPLY}&as=markdown"

    assert_response :success
    response.body.split("\n\n").select { |frame| frame.include?(%(target="#{REPLY}")) }
            .map { |frame| frame.lines.map { |line| line.delete_prefix("data: ") }.join }
  end

  # A frame's prose with its code taken out, as a reader sees it.
  def prose(frame)
    root = Nokogiri::HTML5.fragment(frame[%r{<template>(.*)</template>}m, 1]).at_css('[data-slot="markdown"]')
    root.css('[data-slot="code-block"], code').each(&:remove)
    root.text
  end

  test "the page renders its sections and its three examples" do
    get "/components/markdown"

    assert_response :success
    %w[a-markdown-gem what-reaches-the-page a-reply-being-written headings-in-a-transcript].each do |id|
      assert_select "h2##{id}", 1
    end
    %w[default live unfinished].each do |example|
      assert_includes response.body, "/examples/components/markdown/#{example}"
    end
  end

  test "every example renders standalone" do
    %w[default live unfinished].each do |example|
      get "/examples/components/markdown/#{example}"

      assert_response :success, example
    end
  end

  test "the default example is prose, a code block and a table in a scroller" do
    get "/examples/components/markdown/default"

    assert_select "[data-slot=markdown] h3", text: "Late orders"
    assert_select "[data-slot=markdown] [data-slot=code-block][data-language=ruby]", 1
    assert_select "[data-slot=markdown] .typeset-scroll > table", 1
    assert_select "[data-slot=markdown] a[rel='nofollow noopener noreferrer']", 1
  end

  test "the unfinished example shows the same text raw and closed" do
    get "/examples/components/markdown/unfinished"

    raw, closed = css_select("[data-slot=markdown]")

    assert_includes raw.text, "`Order#la"
    assert_not raw.key?("data-streaming")
    assert_equal "Order#la", closed.at_css("code").text
    assert_equal "", closed["data-streaming"]
  end

  test "the live example asks the scripted reply for Markdown" do
    get "/examples/components/markdown/live"

    assert_equal "/components/composer/messages?as=markdown&composer=markdown-demo", css_select("form#markdown-demo-form").first["action"]

    post "/components/composer/messages?composer=markdown-demo&as=markdown", params: { message: "hi" }

    assert_response :success
    assert_match(%r{src="/components/composer/reply\?as=markdown&amp;composer=markdown-demo&amp;reply=markdown-demo-reply-\h+"}, response.body)
  end

  test "every frame but the last is rendered as still being written" do
    rows = frames

    assert_operator rows.length, :>, 40
    assert(rows[0...-1].all? { |frame| frame.include?('data-streaming=""') })
    assert_not_includes rows.last, "data-streaming"
    assert_includes rows.last, 'data-slot="code-block"'
    assert_includes rows.last, "typeset-scroll"
  end

  test "no frame of the stream shows a raw mark" do
    frames.each_with_index do |frame, index|
      assert_no_match(/\*|`|~~|\||\[|\]/, prose(frame), "frame #{index}")
    end
  end

  test "the plain reply is untouched by the Markdown one" do
    get "/components/composer/reply?composer=composer-demo&reply=composer-demo-reply-0a1b2c3d"

    assert_response :success
    assert_not_includes response.body, 'data-slot="markdown"'
    assert_includes response.body, "whichever comes first."
  end
end
