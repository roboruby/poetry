# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module Markdown
      class ComponentTest < ViewComponent::TestCase
        PARSERS = %i[commonmarker redcarpet].freeze

        REPLY = <<~MARKDOWN
          ## Late orders

          Two orders are **late**, and one is *very* late. See `Order#late?` and
          [the docs](https://example.com/docs "Docs").

          1. ORD-1041
          2. ORD-1039

          ```ruby
          Order.late.where(total: 100..)
          ```

          | Order | Total |
          |:------|------:|
          | ORD-1041 | $482.50 |

          > Ships ~~today~~ tomorrow.
        MARKDOWN

        # A harder reply to cut anywhere: marks inside marks, code that
        # holds backticks, addresses that hold underscores, a tilde fence.
        HARD = <<~MARKDOWN
          ### Summary

          The **`Order#late?`** check is _new_; see [RFC 12](https://example.com/rfc_12?a=1&b=2) and __read it__.

          - A ***very*** important point
          - Use `a_b_c` and ``double `tick` code``

          1. First ~~wrong~~ right
          2. Second with [a link](/orders/1041)

          ~~~text
          plain *stars* stay
          ~~~

          | Left | Right |
          |------|-------|
          | `x`  | **y** |

          Done: see <https://example.com/a_b> and https://example.com/c_d now.
        MARKDOWN

        # What a hostile reply might carry, written as raw HTML and as Markdown.
        HOSTILE = <<~MARKDOWN
          <script>alert(1)</script>
          <img src=x onerror="alert(2)">
          <iframe src="https://evil.example"></iframe>
          <svg><script>alert(3)</script></svg>
          <p style="position:fixed" class="fixed inset-0" id="takeover" onclick="alert(4)">cover</p>
          <a href="javascript:alert(5)" onmouseover="alert(6)">a link</a>
          <form action="https://evil.example"><input name="password"><button>Send</button></form>

          [a label](javascript:alert(7)) and [another](data:text/html,<script>alert(8)</script>)
        MARKDOWN

        def teardown
          MarkdownParser.parser = nil
          MarkdownParser.renderer = nil
        end

        def render_markdown(text, **)
          render_inline(Component.new(text: text, **))
        end

        def each_parser
          PARSERS.each do |parser|
            MarkdownParser.parser = parser
            yield parser
          end
        end

        def test_the_root_is_a_typeset_and_takes_the_caller_classes
          root = render_markdown("Hello", preset: "docs", class: "max-w-xl").at_css('[data-slot="markdown"]')

          assert_equal %w[max-w-xl typeset typeset-docs], root["class"].split.sort
          assert_equal "Hello", root.at_css("p").text
          refute root.key?("data-streaming")
        end

        def test_a_reply_renders_its_blocks_the_same_through_either_parser
          shapes = {}
          each_parser do |parser|
            root = render_markdown(REPLY).at_css('[data-slot="markdown"]')
            shapes[parser] = root.element_children.map { |child| child["data-slot"] || child.name }

            assert_equal "Late orders", root.at_css("h2").text, parser
            assert_equal "late", root.at_css("p strong").text, parser
            assert_equal "very", root.at_css("p em").text, parser
            assert_equal "Order#late?", root.at_css("p code").text, parser
            assert_equal %w[ORD-1041 ORD-1039], root.css("ol li").map(&:text), parser
            assert_equal "today", root.at_css("blockquote del").text, parser
          end

          assert_equal %w[h2 p ol code-block div blockquote], shapes.fetch(:commonmarker)
          assert_equal shapes.fetch(:commonmarker), shapes.fetch(:redcarpet)
        end

        def test_fenced_code_is_a_code_block_in_its_language
          each_parser do |parser|
            block = render_markdown(REPLY).at_css('[data-slot="code-block"]')

            assert_equal "ruby", block["data-language"], parser
            assert_equal "Order.late.where(total: 100..)", block.at_css('[data-slot="code-block-code"]').text.strip,
                         parser
            assert_equal 1, block.css('[data-slot="code-block-copy-button"]').size, parser
          end
        end

        def test_a_language_that_is_not_a_name_is_plain_text
          each_parser do |parser|
            block = render_markdown("```\"><script>alert(1)</script>\nx\n```").at_css('[data-slot="code-block"]')

            assert_equal "text", block["data-language"], parser
            assert_empty render_markdown("```\"><script>alert(1)</script>\nx\n```").css("script"), parser
          end
        end

        def test_a_table_sits_in_a_scroller_with_its_cells_aligned
          each_parser do |parser|
            scroller = render_markdown(REPLY).at_css("div.typeset-scroll")

            assert_equal 1, scroller.css("> table").size, parser
            assert_equal %w[text-left text-right], scroller.css("th").map { |cell| cell["class"] }, parser
            assert_equal %w[text-left text-right], scroller.css("td").map { |cell| cell["class"] }, parser
          end
        end

        def test_a_link_keeps_a_safe_address_and_is_marked_as_not_the_hosts
          each_parser do |parser|
            link = render_markdown(REPLY, link_target: "_blank").at_css("a")

            assert_equal "https://example.com/docs", link["href"], parser
            assert_equal "Docs", link["title"], parser
            assert_equal "nofollow noopener noreferrer", link["rel"], parser
            assert_equal "_blank", link["target"], parser
          end
          refute render_markdown("[x](https://example.com)").at_css("a").key?("target")
        end

        def test_an_address_with_another_scheme_leaves_the_label_alone
          ["javascript:alert(1)", "JAVASCRIPT:alert(1)", "data:text/html,x", "vbscript:x", "java\tscript:alert(1)",
           "file:///etc/passwd"].each do |address|
            each_parser do |parser|
              html = render_markdown("[the label](<#{address}>) after")

              assert_empty html.css("a"), "#{parser}: #{address.inspect}"
              assert_includes html.text, "the label", "#{parser}: #{address.inspect}"
            end
          end
        end

        def test_relative_mail_and_phone_addresses_are_kept
          { "/orders/1041" => "/orders/1041", "#totals" => "#totals", "mailto:a@example.com" => "mailto:a@example.com",
            "tel:+15550100" => "tel:+15550100" }.each do |address, href|
            each_parser do |parser|
              assert_equal href, render_markdown("[x](#{address})").at_css("a")["href"], "#{parser}: #{address}"
            end
          end
        end

        def test_an_image_is_a_link_unless_images_are_asked_for
          each_parser do |parser|
            closed = render_markdown("![Sales chart](https://example.com/chart.png)")
            open = render_markdown("![Sales chart](https://example.com/chart.png)", images: true)

            assert_empty closed.css("img"), parser
            assert_equal ["https://example.com/chart.png", "Sales chart"],
                         [closed.at_css("a")["href"], closed.at_css("a").text], parser
            assert_equal ["https://example.com/chart.png", "Sales chart", "lazy"],
                         open.at_css("img").then { |img| [img["src"], img["alt"], img["loading"]] }, parser
          end
        end

        def test_an_image_from_another_scheme_is_its_alt_text
          each_parser do |parser|
            html = render_markdown("![the alt](data:image/png;base64,AAAA)", images: true)

            assert_empty html.css("img, a"), parser
            assert_includes html.text, "the alt", parser
          end
        end

        def test_headings_start_at_the_level_asked_for_and_stop_at_six
          html = render_markdown("# One\n\n## Two\n\n#### Four\n\n###### Six", heading_level: 3)

          assert_equal %w[h3 h4 h6 h6], html.css("h1, h2, h3, h4, h5, h6").map(&:name)
          assert_raises(ArgumentError) { render_markdown("# One", heading_level: 7) }
        end

        def test_an_ordered_list_keeps_where_it_starts
          each_parser do |parser|
            next if parser == :redcarpet # it restarts every list at one

            assert_equal "3", render_markdown("3. three\n4. four").at_css("ol")["start"], parser
          end
        end

        def test_raw_html_in_the_text_is_shown_as_text
          each_parser do |parser|
            html = render_markdown("Use the <div> tag, never <script>alert(1)</script>.")

            assert_empty html.css("script, div div"), parser
            assert_includes html.text, "Use the <div> tag, never <script>alert(1)</script>.", parser
          end
        end

        # The rebuild is what holds, whatever wrote the HTML: a renderer
        # that passes the text through untouched is the worst parser there is.
        def test_nothing_hostile_survives_even_a_parser_that_passes_everything_through
          renderers = { passthrough: ->(text) { text }, commonmarker: nil, redcarpet: nil }
          renderers.each do |name, renderer|
            MarkdownParser.renderer = renderer
            MarkdownParser.parser = name unless renderer
            root = render_markdown(HOSTILE, images: true).at_css('[data-slot="markdown"]')

            assert_empty root.css("script, iframe, svg, form, input, button, style, object, embed"), name
            assert_empty root.xpath(".//@*[starts-with(name(), 'on')]"), name
            assert_empty root.xpath(".//@style | .//@id"), name
            assert_empty(root.css("[href]").map { |link| link["href"] }.grep(/\A\s*(javascript|data|vbscript):/i), name)
            assert_empty(root.css("[src]").map { |image| image["src"] }.grep_v(%r{\Ahttps?://}), name)
            assert_empty(root.css("[class]").map { |node| node["class"] }.grep(/fixed|inset/), name)
          end
        end

        def test_streaming_closes_what_the_last_block_left_open
          each_parser do |parser|
            written = "Ships **tomorr"
            streamed = render_markdown(written, streaming: true)
            plain = render_markdown(written)

            assert_equal "", streamed.at_css('[data-slot="markdown"]')["data-streaming"], parser
            assert_equal "tomorr", streamed.at_css("strong").text, parser
            assert_empty plain.css("strong"), parser
            assert_includes plain.text, "**tomorr", parser
          end
        end

        # Every prefix of a reply is a frame a reader may see. With
        # streaming: none of them shows a raw mark: no stars, backticks,
        # tildes, pipes or half a link outside code.
        def test_no_frame_of_a_streamed_reply_shows_a_raw_mark
          each_parser do |parser|
            [REPLY, HARD].each do |reply|
              (1..reply.length).each do |length|
                root = render_markdown(reply[0, length], streaming: true).at_css('[data-slot="markdown"]')
                root.css('[data-slot="code-block"], code').each(&:remove)

                refute_match(/\*|`|~~|\||\[|\]|__/, root.text, "#{parser}: after #{reply[0, length].inspect}")
              end
            end
          end
        end

        # The closing is for display only: once the reply is whole, it
        # renders as it would have without it.
        def test_a_finished_reply_renders_the_same_with_or_without_streaming
          each_parser do |parser|
            [REPLY, HARD].each do |reply|
              streamed = render_markdown(reply, streaming: true).at_css('[data-slot="markdown"]')
              settled = render_markdown(reply).at_css('[data-slot="markdown"]')

              assert_equal settled.inner_html, streamed.inner_html, parser
            end
          end
        end

        def test_a_blank_text_is_the_empty_container
          [nil, "", "  \n"].each do |text|
            root = render_markdown(text, streaming: true).at_css('[data-slot="markdown"]')

            assert_empty root.children, text.inspect
          end
        end

        def test_hard_breaks_keep_a_line_break_in_a_paragraph
          each_parser do |parser|
            assert_empty render_markdown("one\ntwo").css("br"), parser
            assert_equal 1, render_markdown("one\ntwo", hard_breaks: true).css("br").size, parser
          end
        end

        def test_without_a_parser_the_text_is_plain_paragraphs_and_code
          MarkdownParser.parser = false
          root = render_markdown("A **bold** claim\nover two lines\n\n```ruby\nputs 1 < 2\n```\n\n<script>x</script>")
                 .at_css('[data-slot="markdown"]')

          assert_equal ["A **bold** claim\nover two lines", "<script>x</script>"], root.css("> p").map(&:text)
          assert_equal 1, root.css("> p br").size
          assert_equal "ruby", root.at_css('[data-slot="code-block"]')["data-language"]
          assert_empty root.css("script, strong")
        end

        def test_a_document_nested_too_deep_to_parse_still_renders
          MarkdownParser.renderer = ->(_text) { "#{"<blockquote>" * 600}deep#{"</blockquote>" * 600}" }
          html = render_markdown("deep")

          assert_includes html.text, "deep"
        end

        def test_text_a_parser_left_outside_a_block_gets_a_paragraph
          MarkdownParser.renderer = ->(_text) { "loose words<p>and a paragraph</p>" }

          assert_equal ["loose words", "and a paragraph"], render_markdown("x").css("p").map(&:text)
        end
      end
    end
  end
end
