# frozen_string_literal: true

require "test_helper"

class MarkdownTest < Minitest::Test
  Markdown = Poetry::Agent::A2UI::Markdown

  def test_renders_headings_paragraphs_lists_and_inline_marks
    html = Markdown.render("## Login\n\nWelcome **back**, *Ada* `x` [site](https://a.b)\nsecond line\n\n- one\n- two")

    assert_equal "<h2>Login</h2><p>Welcome <strong>back</strong>, <em>Ada</em> <code>x</code> " \
                 '<a href="https://a.b">site</a><br>second line</p><ul><li>one</li><li>two</li></ul>', html
  end

  def test_escapes_markup_and_ignores_non_http_links
    html = Markdown.render("<b>no</b> [x](javascript:alert(1))")

    assert_equal "<p>&lt;b&gt;no&lt;/b&gt; [x](javascript:alert(1))</p>", html
  end

  def test_strip_removes_markers
    assert_equal "Login back Ada site", Markdown.strip("## Login **back** *Ada* [site](https://a.b)")
  end

  def test_empty_text_renders_nothing
    assert_equal "", Markdown.render("")
    assert_equal "", Markdown.render(nil)
  end
end
