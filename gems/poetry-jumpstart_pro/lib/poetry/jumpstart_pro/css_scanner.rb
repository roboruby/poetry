# frozen_string_literal: true

module Poetry
  module JumpstartPro
    # A small top-level CSS scanner for the stylesheet reconciliation: it
    # splits a stylesheet into statements, skipping comments and strings, so
    # an edit can drop whole rules without a CSS parser dependency.
    #
    # @example List a stylesheet's top-level selectors
    #   Poetry::JumpstartPro::CssScanner.each_statement("a { color: red; }") { |_, prelude, _| prelude }
    module CssScanner
      # The characters that open a CSS string.
      QUOTES = ['"', "'"].freeze

      module_function

      # Walks the top level of a stylesheet, yielding each statement's full
      # text (with the whitespace and comments before it), its prelude (nil
      # for bare whitespace or comments), and its block body. Braces inside
      # comments and strings do not count.
      # @api private
      def each_statement(css)
        index = 0
        while index < css.length
          start = index
          index = skip_trivia(css, index)
          if index >= css.length
            yield css[start..], nil, nil
            break
          end

          open = scan_to(css, index, "{;")
          if open.nil?
            yield css[start..], nil, nil
            break
          end
          prelude = css[index...open].strip
          if css[open] == ";"
            index = open + 1
            yield css[start...index], prelude, nil
            next
          end

          close = matching_brace(css, open)
          index = close + 1
          index += 1 while index < css.length && css[index] =~ /[ \t]/
          index += 1 if css[index] == "\n"
          yield css[start...index], prelude, css[(open + 1)...close]
        end
      end

      # Skips whitespace and comments from index.
      # @api private
      def skip_trivia(css, index)
        loop do
          index += 1 while index < css.length && css[index] =~ /\s/
          break unless css[index, 2] == "/*"

          finish = css.index("*/", index + 2)
          return css.length if finish.nil?

          index = finish + 2
        end
        index
      end

      # The index of the first of the given characters outside comments and
      # strings, or nil.
      # @api private
      def scan_to(css, index, characters)
        while index < css.length
          if css[index, 2] == "/*"
            finish = css.index("*/", index + 2) or return nil
            index = finish + 2
            next
          end
          if QUOTES.include?(css[index])
            index = skip_string(css, index)
            next
          end
          return index if characters.include?(css[index])

          index += 1
        end
        nil
      end

      # The index of the brace closing the one at open.
      # @api private
      def matching_brace(css, open)
        depth = 0
        index = open
        while index < css.length
          if css[index, 2] == "/*"
            index = (css.index("*/", index + 2) || css.length) + 2
            next
          end
          if QUOTES.include?(css[index])
            index = skip_string(css, index)
            next
          end
          depth += 1 if css[index] == "{"
          depth -= 1 if css[index] == "}"
          return index if depth.zero?

          index += 1
        end
        css.length - 1
      end

      # The index just past the string starting at index.
      # @api private
      def skip_string(css, index)
        quote = css[index]
        index += 1
        index += css[index] == "\\" ? 2 : 1 while index < css.length && css[index] != quote
        index + 1
      end
    end
  end
end
