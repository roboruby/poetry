# frozen_string_literal: true

require "erb"

module Poetry
  module Ui
    # The CodeBlock's rouge seam: highlighting is a SOFT capability -
    # `gem "rouge"` in the host Gemfile turns it on; without it the component
    # renders the plain escaped code unchanged (the fallback is simply
    # "no rouge", and nothing shifts because the markup shape is identical).
    module CodeBlockHighlighter
      module_function

      # Whether rouge is loadable in this host (memoized).
      #
      # @return [Boolean]
      def available?
        return @available if defined?(@available)

        @available = begin
          require "rouge"
          true
        rescue LoadError
          false
        end
      end

      # The source's lines as they render: one entry per line, the final
      # newline not starting an extra one ("a\nb\n" is two lines). An empty
      # source is one empty line.
      #
      # @param code [String] the source
      # @return [Array<String>]
      def source_lines(code)
        code.to_s.chomp.split("\n", -1).then { |lines| lines.empty? ? [""] : lines }
      end

      # -> one html_safe fragment per source line: rouge's token spans when
      # rouge is present (unknown languages lex as plain text), the escaped
      # text otherwise. The count always matches {source_lines}, so a line's
      # position is its number.
      #
      # @param lines [Array<String>] the source lines (see {source_lines})
      # @param language [String, Symbol, nil] the rouge lexer name
      # @return [Array<ActiveSupport::SafeBuffer>]
      def highlight_lines(lines, language:)
        fragments = available? ? rouge_lines(lines.join("\n"), language) : lines.map { |line| ERB::Util.html_escape(line) }
        fragments.fill("".html_safe, fragments.length...lines.length).first(lines.length).map(&:html_safe)
      end

      # Rouge's tokens grouped per line, each line its joined token spans.
      #
      # @param code [String]
      # @param language [String, Symbol, nil]
      # @return [Array<String>]
      # @api private
      def rouge_lines(code, language)
        lexer = Rouge::Lexer.find(language.to_s) || Rouge::Lexers::PlainText.new
        line_formatter.lines(lexer.lex(code))
      end

      # Rouge's HTML formatter, reading its (protected) line grouping.
      #
      # @return [Rouge::Formatters::HTML]
      # @api private
      def line_formatter
        @line_formatter ||= Class.new(Rouge::Formatters::HTML) do
          def lines(tokens) = token_lines(tokens).map { |line| line.map { |token, value| span(token, value) }.join }
        end.new
      end
    end
  end
end
