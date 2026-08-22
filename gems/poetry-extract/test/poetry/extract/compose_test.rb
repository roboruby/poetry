# frozen_string_literal: true

require "test_helper"

module Poetry
  module Extract
    class ComposeTest < Minitest::Test
      def signals(screenshot: "https://cdn.example/shot.png")
        Signals.new(styleguide: { "mode" => "light" }, brand: nil,
                    screenshot_url: screenshot, markdown: "# Home\n\nBody text.")
      end

      def canned(design_md)
        { "content" => [{ "type" => "text", "text" => design_md }] }
      end

      def test_composes_with_screenshot_image_block_and_prompt_shape
        captured = nil
        result = Compose.design_md(domain: "example.com", signals: signals,
                                   http: lambda { |payload|
                                     captured = payload
                                     canned("---\nversion: alpha\n---\n\n# Example")
                                   })

        assert_equal "---\nversion: alpha\n---\n\n# Example", result
        assert_in_delta(0.2, captured[:temperature])
        assert_equal Compose::SYSTEM, captured[:system]

        content = captured[:messages].first[:content]

        assert_equal "image", content.first[:type]
        assert_equal "https://cdn.example/shot.png", content.first.dig(:source, :url)
        prompt = content.last[:text]

        assert_includes prompt, "Generate a polished DESIGN.md document for example.com."
        assert_includes prompt, "version: alpha"
        assert_includes prompt, %("mode": "light")
        assert_includes prompt, "# Home"
      end

      def test_no_screenshot_means_text_only_content_and_placeholder
        captured = nil
        Compose.design_md(domain: "example.com", signals: signals(screenshot: nil),
                          http: lambda { |payload|
                            captured = payload
                            canned("x")
                          })
        content = captured[:messages].first[:content]

        assert_equal 1, content.length
        assert_equal "text", content.first[:type]
        assert_includes content.first[:text], "No screenshot returned."
      end

      def test_markdown_excerpt_truncates_at_3000_chars
        long = Signals.new(styleguide: nil, brand: nil, screenshot_url: nil, markdown: "m" * 9000)
        captured = nil
        Compose.design_md(domain: "example.com", signals: long,
                          http: lambda { |payload|
                            captured = payload
                            canned("x")
                          })

        assert_includes captured[:messages].first[:content].first[:text], "m" * 3000
        refute_includes captured[:messages].first[:content].first[:text], "m" * 3001
      end
    end
  end
end
