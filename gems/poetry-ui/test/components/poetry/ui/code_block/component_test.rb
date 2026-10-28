# frozen_string_literal: true

require "test_helper"

module Poetry
  module Ui
    module CodeBlock
      class ComponentTest < ViewComponent::TestCase
        SNIPPET = "def hello\n  puts \"hi\"\nend\n"

        def render_block(code: SNIPPET, language: "ruby", **, &)
          render_inline(Component.new(code:, language:, **), &)
          Nokogiri::HTML5.fragment(rendered_content)
        end

        def lines(fragment) = fragment.css('[data-slot="code-block-line"]')

        # minitest 6 has no stub: swap the capability probe for the block.
        def without_rouge
          original = CodeBlockHighlighter.method(:available?)
          CodeBlockHighlighter.define_singleton_method(:available?) { false }
          yield
        ensure
          CodeBlockHighlighter.define_singleton_method(:available?, original)
        end

        def test_renders_upstreams_anatomy
          fragment = render_block
          root = fragment.at_css('[data-slot="code-block"]')
          pre = root.at_css('pre[data-slot="code-block-content"]')

          assert_equal "default", root["data-variant"]
          assert_equal "default", root["data-size"]
          assert_equal "ruby", root["data-language"]
          assert_includes root["class"].split, "cn-code-block"
          assert_includes root["class"].split, "cn-code-block-variant-default"
          assert_equal "0", pre["tabindex"]
          assert_equal "region", pre["role"]
          assert_equal "ltr", pre["dir"], "code reads left to right on an RTL page"
          assert pre.at_css('code[data-slot="code-block-code"]')
        end

        def test_every_source_line_is_a_line_part
          fragment = render_block

          assert_equal 3, lines(fragment).size
          assert_equal(%w[default default default], lines(fragment).map { |line| line["data-variant"] })
          assert_equal "end", lines(fragment).last.at_css('[data-slot="code-block-line-content"]').text
        end

        def test_copied_text_keeps_the_line_breaks
          code = render_block.at_css('[data-slot="code-block-code"]')

          assert_equal SNIPPET, code.text, "the engine copies the code element's textContent"
        end

        def test_rouge_colors_tokens_through_the_palette
          code = render_block.at_css('[data-slot="code-block-code"]')

          assert code.at_css("span.k"), "rouge's keyword token"
          assert_includes code["class"], "text-(--syntax-keyword)"
        end

        def test_without_rouge_the_markup_is_identical_and_plain
          without_rouge do
            fragment = render_block(code: "a < b\nc\n")

            assert_equal 2, lines(fragment).size
            assert_nil fragment.at_css("span.k")
            assert_equal "a < b", lines(fragment).first.text
          end
        end

        def test_line_numbers_number_the_content_and_start_where_asked
          pre = render_block(line_numbers: true).at_css("pre")

          assert pre.key?("data-numbered")
          assert_nil pre["style"], "the dictionary's counter-reset starts at 1"

          started = render_block(line_numbers: true, start_line: 40).at_css("pre")

          assert_equal "counter-reset: line 39", started["style"]
        end

        def test_highlight_lines_tint_by_position
          variants = lines(render_block(highlight_lines: [2])).map { |line| line["data-variant"] }

          assert_equal %w[default highlighted default], variants
          assert_includes lines(render_block(highlight_lines: [2]))[1]["class"],
                          "cn-code-block-line-variant-highlighted"
        end

        def test_diff_marks_lines_and_copies_the_markers
          patch = " def hello\n-  puts \"hi\"\n+  puts \"hello\"\n end\n"
          fragment = render_block(code: patch, diff: true)

          assert_equal(%w[default removed added default], lines(fragment).map { |line| line["data-variant"] })
          assert_equal "  puts \"hello\"", lines(fragment)[2].text, "the marker is the theme's to draw"
          root = fragment.at_css('[data-slot="code-block"]')

          assert_equal patch, root["data-poetry--core--clipboard-text-text-value"]
        end

        def test_a_title_opens_the_header_and_names_the_region
          fragment = render_block { |block| block.with_title { "hello.rb" } }
          header = fragment.at_css('[data-slot="code-block-header"]')
          title = header.at_css('[data-slot="code-block-title"]')

          assert_equal "hello.rb", title.text
          assert header.at_css('[data-slot="code-block-actions"] [data-slot="code-block-copy-button"]'),
                 "the copy button moves into the header"
          assert_equal title["id"], fragment.at_css("pre")["aria-labelledby"]
        end

        def test_without_a_header_the_actions_float_before_the_content
          root = render_block.at_css('[data-slot="code-block"]')

          assert_equal(%w[code-block-actions code-block-content], root.element_children.map do |child|
            child["data-slot"]
          end)
          assert_equal "Code", root.at_css("pre")["aria-label"]
        end

        def test_copy_false_renders_no_actions
          fragment = render_block(copy: false)

          assert_nil fragment.at_css('[data-slot="code-block-actions"]')
          refute fragment.at_css('[data-slot="code-block"]').key?("data-controller")
        end

        def test_footer_wrap_variant_and_size
          fragment = render_block(wrap: true, variant: :destructive, size: :sm) do |block|
            block.with_footer do
              "exit 1"
            end
          end
          root = fragment.at_css('[data-slot="code-block"]')

          assert_equal "exit 1", fragment.at_css('[data-slot="code-block-footer"]').text
          assert fragment.at_css("pre").key?("data-wrap")
          assert_equal "destructive", root["data-variant"]
          assert_equal "sm", root["data-size"]
          assert_includes root["class"], "cn-code-block-variant-destructive"
        end

        def test_rejects_an_unknown_size
          assert_raises(ArgumentError) { render_block(size: :lg) }
        end
      end
    end
  end
end
