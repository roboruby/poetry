# frozen_string_literal: true

module Poetry
  module Ui
    # The CodeBlock's rouge seam: highlighting is a SOFT capability -
    # `gem "rouge"` in the host Gemfile turns it on; without it the component
    # renders the plain escaped code unchanged (kumo ships a plain-text
    # fallback while Shiki loads; server-side the fallback is simply
    # "no rouge", and nothing shifts because the markup shape is identical).
    module CodeBlockHighlighter
      module_function

      def available?
        return @available if defined?(@available)

        @available = begin
          require "rouge"
          true
        rescue LoadError
          false
        end
      end

      # -> html_safe highlighted markup - every line wrapped in .line (the
      # counter hook), the requested ones also .hll (the theme's tint hook) -
      # or nil when rouge is absent. Unknown languages lex as plain text.
      def highlight(code, language:, highlight_lines: [])
        return nil unless available?

        lexer = Rouge::Lexer.find(language.to_s) || Rouge::Lexers::PlainText.new
        formatter.new(highlight_lines: Array(highlight_lines).map(&:to_i))
                 .format(lexer.lex(code)).html_safe
      end

      # Rouge 5 asserts a PLAIN HTML delegate inside its line-wise wrappers
      # (HTMLLinewise cannot wrap HTMLLineHighlighter), so poetry carries its
      # own line formatter over the stable token_lines API.
      def formatter
        @formatter ||= Class.new(Rouge::Formatters::HTML) do
          def initialize(highlight_lines: [])
            super()
            @highlight_lines = highlight_lines
          end

          def stream(tokens)
            token_lines(tokens).each.with_index(1) do |line_tokens, lineno|
              classes = ["line"]
              classes << "hll" if @highlight_lines.include?(lineno)
              yield %(<span class="#{classes.join(" ")}">)
              line_tokens.each { |token, value| yield span(token, value) }
              yield "</span>\n"
            end
          end
        end
      end
    end
  end
end
