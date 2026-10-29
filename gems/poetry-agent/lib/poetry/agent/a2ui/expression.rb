# frozen_string_literal: true

require "strscan"

module Poetry
  module Agent
    module A2UI
      # The `formatString` grammar: literal text with `${...}` blocks, each
      # block a data path, a literal, or a function call whose arguments are
      # named (`name: expression`, comma separated, a trailing comma allowed)
      # and are expressions again; `\${` is a literal `${`. Parsing yields a
      # plain tree the {Evaluator} walks:
      #
      #   [:template, nodes]           the whole string
      #   [:text, "literal text"]
      #   [:path, "/absolute"]         or a relative path (`name`, `./name`, `../name`)
      #   [:literal, 12] / [:literal, "quoted"] / [:literal, true]
      #   [:call, "formatDate", { "value" => node, "format" => node }]
      #
      # The spec's rules: a path is a run of identifier characters, `/`, `.`
      # and `-` (Poetry adds `~`, so a JSON Pointer's escapes read); a
      # number takes an optional sign, a mantissa (`5`, `5.`, `5.25`, `.5`)
      # and an optional exponent, and is an error outside the double range
      # and zero below it; a string unescapes `\n`, `\t` and `\r` and keeps
      # any other escaped character; `null` reads as the empty string;
      # nesting stops at {MAX_DEPTH}.
      #
      # @example
      #   Expression.parse("Hi ${/user/name}, ${formatNumber(value: ${/n}, decimals: 1)}")
      module Expression
        # A malformed expression.
        class SyntaxError < StandardError; end

        # Identifier: function and argument names.
        IDENT = /[\p{XID_Start}_]\p{XID_Continue}*/
        # A path or a function name (a system function's carries a leading `@`).
        TOKEN = %r{@?[\p{XID_Continue}/.~-]+}
        # A function name: an identifier, or `@` and one.
        FUNCTION = /\A@?#{IDENT.source}\z/
        # Where a number literal starts: a digit, or a point and a digit, after an optional sign.
        NUMBER_START = /[+-]?\.?[0-9]/
        # The characters a number literal spans, checked against {NUMBER} afterwards.
        NUMBER_SPAN = /[+-]?[0-9.]*(?:[eE][+-]?[0-9]*)?/
        # A well-formed number literal.
        NUMBER = /\A[+-]?(?:[0-9]+\.?[0-9]*|\.[0-9]+)(?:[eE][+-]?[0-9]+)?\z/
        # A quoted string literal, its body in the first or second group.
        STRING = /'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)"/m
        # The escapes a string literal translates; any other escaped character stands for itself.
        ESCAPES = { "n" => "\n", "t" => "\t", "r" => "\r" }.freeze
        # Keyword literals (the spec reads `null` as the empty string).
        KEYWORDS = { "true" => true, "false" => false, "null" => "" }.freeze
        # Nesting depth beyond which an expression is refused: each block and each call argument is a level.
        MAX_DEPTH = 100
        # The smallest magnitude that rounds to an infinite double.
        OVERFLOW = (2**1024) - (2**970)
        # The largest magnitude that rounds to zero.
        UNDERFLOW = Rational(1, 2**1075)

        module_function

        # The template tree of an expression string.
        # @param text [String]
        # @return [Array] the `[:template, nodes]` tree
        # @raise [SyntaxError]
        def parse(text)
          Parser.new(text.to_s).template
        end

        # Whether the text carries an interpolation block.
        # @param text [String]
        # @return [Boolean] whether the text carries an interpolation block
        def dynamic?(text)
          text.is_a?(String) && text.include?("${")
        end

        # The recursive-descent parser.
        class Parser
          # A parser over the source, at its start.
          # @param source [String]
          # @raise [SyntaxError] when the source is not UTF-8 text
          def initialize(source)
            @source = utf8(source)
            @scanner = StringScanner.new(@source)
          end

          # The template tree: literal runs and interpolation blocks.
          # @return [Array] the `[:template, nodes]` tree
          def template
            nodes = []
            buffer = +""
            until @scanner.eos?
              if @scanner.skip(/\\\$\{/)
                buffer << "${"
              elsif @scanner.check(/\$\{/)
                nodes << [:text, buffer] unless buffer.empty?
                buffer = +""
                nodes << block(1)
              else
                buffer << @scanner.scan(/[^\\$]+|./m)
              end
            end
            nodes << [:text, buffer] unless buffer.empty?
            [:template, nodes]
          end

          private

          # The source as UTF-8, a binary string read as UTF-8 bytes; the
          # grammar's identifier characters are Unicode properties.
          def utf8(source)
            binary = source.encoding == Encoding::BINARY
            text = binary ? source.dup.force_encoding(Encoding::UTF_8) : source.encode(Encoding::UTF_8)
            raise SyntaxError, "Expression is not valid UTF-8" unless text.valid_encoding?

            text
          rescue EncodingError
            raise SyntaxError, "Expression is not valid UTF-8"
          end

          # `${` expression `}`, the expression at the given depth. The
          # closing brace is found first, so an unclosed block reports as
          # one whatever it holds.
          def block(depth)
            @scanner.skip(/\$\{/)
            close = closing_brace
            node = expression(depth)
            @scanner.skip(/\s*/)
            unless @scanner.pos == close
              rest = @source.byteslice(@scanner.pos...close)
              raise SyntaxError, "Unexpected characters at end of expression: '#{rest}'"
            end

            @scanner.pos = close + 1
            node
          end

          # The byte offset of the `}` closing the block that starts at the
          # scanner: braces balance, and quoted strings are skipped whole.
          def closing_brace
            probe = @scanner.dup
            open = 1
            loop do
              probe.skip(/[^{}'"]+/)
              next if probe.skip(STRING)

              case probe.getch
              when "{" then open += 1
              when "}" then return probe.pos - 1 if (open -= 1).zero?
              else raise SyntaxError, "Unclosed interpolation: missing '}'"
              end
            end
          end

          # One expression node: a nested block, a string, a number, a keyword, a path or a call.
          def expression(depth)
            if depth > MAX_DEPTH
              raise SyntaxError, "Max recursion depth reached: expressions nest at most #{MAX_DEPTH} deep"
            end

            @scanner.skip(/\s*/)
            if @scanner.check(/\$\{/) then block(depth + 1)
            elsif @scanner.scan(STRING) then [:literal, unescape(@scanner[1] || @scanner[2])]
            elsif @scanner.match?(NUMBER_START) then [:literal, number(@scanner.scan(NUMBER_SPAN))]
            else token(depth)
            end
          end

          # A keyword, a path, or (followed by `(`) a function call.
          def token(depth)
            text = @scanner.scan(TOKEN) or raise SyntaxError, "Expected an expression, found '#{@scanner.check(/./m)}'"
            return [:literal, KEYWORDS[text]] if KEYWORDS.key?(text)
            return [:path, text] unless @scanner.skip(/\s*\(/)
            raise SyntaxError, "Invalid function name '#{text}'" unless FUNCTION.match?(text)

            [:call, text, arguments(text, depth)]
          end

          # The named arguments of a call, up to the closing parenthesis;
          # each argument's expression is one level deeper than the call.
          def arguments(function, depth)
            args = {}
            until @scanner.skip(/\s*\)/)
              if @scanner.match?(/\s*(?:\}|\z)/)
                raise SyntaxError, "Expected ')' after function arguments for '#{function}'"
              end

              args[argument_name(function)] = expression(depth + 1)
              next if @scanner.skip(/\s*,/) || @scanner.match?(/\s*\)/)

              raise SyntaxError, "Expected ',' or ')' after function arguments for '#{function}'"
            end
            args
          end

          # An argument's name and its colon; a positional argument has neither.
          def argument_name(function)
            @scanner.skip(/\s*/)
            name = @scanner.scan(IDENT)
            return name if name && @scanner.skip(/\s*:/)

            raise SyntaxError, "Expected ':' after argument name '#{name}' in function '#{function}'" if name

            raise SyntaxError, "Expected ':' after argument name in function '#{function}': arguments are named"
          end

          # A number literal's value: an Integer, or a Float when it has a
          # point or an exponent. Past the double range it is an error;
          # below it, zero.
          def number(text)
            raise SyntaxError, "Invalid number literal: '#{text}'" unless NUMBER.match?(text)

            value = text.match?(/[.eE]/) ? magnitude(text) : Integer(text, 10)
            raise SyntaxError, "Number literal is out of range: '#{text}'" if value.abs >= OVERFLOW
            return value if value.is_a?(Integer)

            value <= UNDERFLOW ? 0.0 : Float(text)
          end

          # The exact magnitude of a decimal literal, so the range checks
          # never round; a literal whose order of magnitude is far outside the
          # double range stands in as OVERFLOW or zero, unexpanded.
          def magnitude(text)
            whole, fraction, exponent = text.match(/\A[+-]?([0-9]*)\.?([0-9]*)(?:[eE]([+-]?[0-9]+))?\z/).captures
            digits = "#{whole}#{fraction}".sub(/\A0+/, "")
            return 0r if digits.empty?

            scale = exponent.to_i - fraction.length
            order = digits.length + scale # 10**(order - 1) <= magnitude < 10**order
            return OVERFLOW if order > 309
            return 0r if order < -323

            digits.to_i * (10r**scale)
          end

          # A string literal's body with its backslash escapes translated.
          def unescape(text)
            text.gsub(/\\(.)/m) { ESCAPES.fetch(Regexp.last_match(1), Regexp.last_match(1)) }
          end
        end
      end
    end
  end
end
