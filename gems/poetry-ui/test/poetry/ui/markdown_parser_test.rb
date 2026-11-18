# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The parser seam: which gem writes the HTML, how a host names another,
    # and what is rendered when there is none.
    class MarkdownParserTest < Minitest::Test
      def teardown
        MarkdownParser.parser = nil
        MarkdownParser.renderer = nil
      end

      def test_commonmarker_is_preferred_when_the_host_bundles_both
        assert_equal :commonmarker, MarkdownParser.parser
        assert_predicate MarkdownParser, :available?
      end

      def test_a_host_can_name_the_parser_or_ask_for_the_plain_rendering
        MarkdownParser.parser = :redcarpet

        assert_equal :redcarpet, MarkdownParser.parser

        MarkdownParser.parser = false

        assert_nil MarkdownParser.parser
        refute_predicate MarkdownParser, :available?
        assert_equal "<p>**plain**</p>\n", MarkdownParser.to_html("**plain**")

        MarkdownParser.parser = nil

        assert_equal :commonmarker, MarkdownParser.parser
      end

      def test_a_parser_it_does_not_know_is_refused
        assert_raises(ArgumentError) { MarkdownParser.parser = :kramdown }
      end

      def test_a_hosts_renderer_takes_the_place_of_the_gems
        MarkdownParser.renderer = ->(text) { "<p>#{text.upcase}</p>" }

        assert_equal :custom, MarkdownParser.parser
        assert_equal "<p>HELLO</p>", MarkdownParser.to_html("hello")
      end

      def test_each_gem_writes_the_same_marks
        %i[commonmarker redcarpet].each do |gem_name|
          html = MarkdownParser.to_html("A **bold** word and `code`.\n\n```ruby\nputs 1\n```\n", with: gem_name)

          assert_includes html, "<strong>bold</strong>", gem_name
          assert_includes html, "<code>code</code>", gem_name
          assert_match(%r{<pre[^>]*><code[^>]*>puts 1\n</code></pre>}, html, gem_name)
        end
      end

      def test_raw_html_is_escaped_by_either_gem
        %i[commonmarker redcarpet].each do |gem_name|
          html = MarkdownParser.to_html("Use the <div> tag.\n\n<script>alert(1)</script>\n", with: gem_name)

          refute_includes html, "<script>", gem_name
          refute_includes html, "<div>", gem_name
          assert_includes html, "&lt;div&gt;", gem_name
        end
      end

      def test_hard_breaks_reach_either_gem
        %i[commonmarker redcarpet].each do |gem_name|
          refute_includes MarkdownParser.to_html("one\ntwo", with: gem_name), "<br", gem_name
          assert_includes MarkdownParser.to_html("one\ntwo", hard_breaks: true, with: gem_name), "<br", gem_name
        end
      end

      def test_the_plain_rendering_keeps_paragraphs_line_breaks_and_fenced_code
        html = MarkdownParser.plain("One <b>line</b>\nand another\n\n```ruby\nputs 1 < 2\n```\n\n~~~\nstill open")

        assert_equal "<p>One &lt;b&gt;line&lt;/b&gt;<br>\nand another</p>\n" \
                     "<pre><code class=\"language-ruby\">puts 1 &lt; 2</code></pre>\n" \
                     "<pre><code>still open</code></pre>\n", html
      end
    end
  end
end
