# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    # The tail closer: each case is a reply cut where a stream might cut
    # it, and what it should read as until the rest arrives.
    class MarkdownTailTest < Minitest::Test
      CASES = {
        # Emphasis: closed where it stands, innermost first.
        "Ships **tomorr" => "Ships **tomorr**",
        "Ships *soon" => "Ships *soon*",
        "~~gone" => "~~gone~~",
        "**bold and _nested" => "**bold and _nested_**",
        "trailing space **bold " => "trailing space **bold** ",
        "- item **one**\n- item **tw" => "- item **one**\n- item **tw**",
        # A mark with nothing after it yet is taken out, not closed.
        "Here is **" => "Here is ",
        "word **" => "word ",
        # A closing mark half arrived is completed.
        "Here is **bold*" => "Here is **bold**",
        "Ships ~~today~" => "Ships ~~today~~",
        "About ~5 minutes" => "About ~5 minutes",
        # Code spans, with the marks opened before them.
        "Use `Arr" => "Use `Arr`",
        "Use `" => "Use ",
        "Use ``a ` b" => "Use ``a ` b``",
        "Use ``a `" => "Use ``a ` ``",
        "**bold `co" => "**bold `co`**",
        # A link whose address is still being written is its label; an image is nothing.
        "See [the fulf" => "See the fulf",
        "See [the docs]" => "See the docs",
        "**see [the do" => "**see the do**",
        "Chart: ![sales ch" => "Chart: ",
        "Chart: ![sales chart]" => "Chart: ",
        "See [the docs](https://exam" => "See the docs",
        "See [the docs](https://example.com \"Our do" => "See the docs",
        "Chart: ![sales](https://ex" => "Chart: ",
        # A table's first row is a table at once; a row that is only its pipe waits.
        "Totals:\n\n|" => "Totals:\n\n",
        "| Name | Qty |" => "| Name | Qty |\n| --- | --- |\n",
        "| Name | Qty |\n|--" => "| Name | Qty |\n| --- | --- |\n",
        "| Name | Qty |\n| --- | --- |\n| Apple | 3" => "| Name | Qty |\n| --- | --- |\n| Apple | 3",
        "| Name | Qty |\n| --- | --- |\n| Apple | 3 |\n|" => "| Name | Qty |\n| --- | --- |\n| Apple | 3 |\n",
        # Only the last block is read.
        "```ruby\nputs 1\n```\n\nAfter **th" => "```ruby\nputs 1\n```\n\nAfter **th**",
        "An *open mark\n\nand a new block" => "An *open mark\n\nand a new block"
      }.freeze

      UNTOUCHED = [
        "Ships **tomorrow**",
        "See [the docs](https://example.com)",
        "snake_case_name and more",
        "5 * 3 = 15",
        "a [b] c",
        "`items[0` is code",
        "Call items[0](see below and more",
        "* a bullet",
        "a \\*literal",
        "x `code` and more",
        "Text\n\n***\n",
        "Done.\n\n",
        "",
        # Inside an open fence nothing is closed: a parser reads it to the end.
        "Before\n\n```ruby\nputs **x",
        "~~~\nan `open span"
      ].freeze

      def test_what_a_stream_left_open_is_closed
        CASES.each do |written, shown|
          assert_equal shown, MarkdownTail.close(written), "for #{written.inspect}"
        end
      end

      def test_finished_text_is_returned_as_it_is
        UNTOUCHED.each do |text|
          assert_equal text, MarkdownTail.close(text), "for #{text.inspect}"
        end
      end

      def test_nil_is_an_empty_reply
        assert_equal "", MarkdownTail.close(nil)
      end

      def test_closing_twice_changes_nothing_more
        CASES.each_value do |shown|
          assert_equal shown, MarkdownTail.close(shown), "for #{shown.inspect}"
        end
      end
    end
  end
end
