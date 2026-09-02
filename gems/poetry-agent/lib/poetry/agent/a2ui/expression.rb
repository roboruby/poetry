# frozen_string_literal: true

module Poetry
  module Agent
    module A2UI
      # The `formatString` grammar: literal text with `${...}` blocks, each
      # block a data path, a literal, or a function call with named
      # arguments whose values are expressions again (a bare argument is
      # `value`); `\${` is a literal `${`. Parsing yields a plain tree the
      # {Evaluator} walks:
      #
      #   [:template, nodes]           the whole string
      #   [:text, "literal text"]
      #   [:path, "/absolute"]         or a relative path
      #   [:literal, 12] / [:literal, "quoted"] / [:literal, true]
      #   [:call, "formatDate", { "value" => node, "format" => node }]
      #
      # @example
      #   Expression.parse("Hi ${/user/name}, ${formatNumber(value: ${/n}, decimals: 1)}")
      module Expression
        # A malformed expression.
        class SyntaxError < StandardError; end

        # Identifier: function names, argument names, relative path heads.
        IDENT = /[A-Za-z_@][A-Za-z0-9_]*/
        # A number literal not followed by a path or identifier character.
        NUMBER = %r{-?\d+(?:\.\d+)?(?![\w/])}
        # Keyword literals.
        KEYWORDS = { "true" => true, "false" => false, "null" => nil }.freeze
        # Nesting depth beyond which an expression is refused.
        MAX_DEPTH = 32

        module_function

        # @param text [String]
        # @return [Array] the `[:template, nodes]` tree
        # @raise [SyntaxError]
        def parse(text)
          Parser.new(text.to_s).template
        end

        # @param text [String]
        # @return [Boolean] whether the text carries an interpolation block
        def dynamic?(text)
          text.is_a?(String) && text.include?("${")
        end

        # The recursive-descent parser.
        class Parser
          # @param source [String]
          def initialize(source)
            @source = source
            @index = 0
            @depth = 0
          end

          # @return [Array] the `[:template, nodes]` tree
          def template
            nodes = []
            buffer = +""
            until eos?
              if peek(3) == "\\${"
                buffer << "${"
                @index += 3
              elsif peek(2) == "${"
                nodes << [:text, buffer] unless buffer.empty?
                buffer = +""
                nodes << block
              else
                buffer << @source[@index]
                @index += 1
              end
            end
            nodes << [:text, buffer] unless buffer.empty?
            [:template, nodes]
          end

          private

          # `${` expression `}`
          def block
            expect("${")
            node = expression
            skip_space
            expect("}")
            node
          end

          def expression
            @depth += 1
            raise SyntaxError, "expression nested deeper than #{MAX_DEPTH}" if @depth > MAX_DEPTH

            skip_space
            node = if peek(2) == "${" then block
                   elsif (match = scan(/'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)"/))
                     [:literal, unescape(match[1] || match[2])]
                   elsif (match = scan(NUMBER)) then [:literal, number(match[0])]
                   elsif (match = scan(%r{(true|false|null)(?![\w/])})) then [:literal, KEYWORDS[match[1]]]
                   elsif peek(1) == "/" then [:path, scan(%r</[^\s,)}]*>)[0]]
                   elsif (match = scan(IDENT)) then identifier(match[0])
                   else raise SyntaxError, "unexpected #{peek(1).inspect} at #{@index}"
                   end
            @depth -= 1
            node
          end

          # A name followed by `(` is a call; otherwise a relative path.
          def identifier(name)
            skip_space
            return [:path, name + (scan(%r<(?:/[^\s,)}/]*)*>)&.[](0) || "")] unless peek(1) == "("

            @index += 1
            [:call, name, arguments]
          end

          def arguments
            args = {}
            skip_space
            if peek(1) == ")"
              @index += 1
              return args
            end
            loop do
              skip_space
              named = scan(/(#{IDENT.source})\s*:/)
              args[named ? named[1] : "value"] = expression
              skip_space
              case peek(1)
              when "," then @index += 1
              when ")"
                @index += 1
                return args
              else raise SyntaxError, "expected , or ) at #{@index}"
              end
            end
          end

          def number(text)
            text.include?(".") ? Float(text) : Integer(text, 10)
          end

          def unescape(text)
            text.gsub(/\\(.)/) { Regexp.last_match(1) }
          end

          def scan(pattern)
            match = pattern.match(@source, @index)
            return unless match && match.begin(0) == @index

            @index = match.end(0)
            match
          end

          def expect(token)
            raise SyntaxError, "expected #{token.inspect} at #{@index}" unless peek(token.length) == token

            @index += token.length
          end

          def peek(length)
            @source[@index, length]
          end

          def skip_space
            @index += 1 while @source[@index]&.match?(/\s/)
          end

          def eos?
            @index >= @source.length
          end
        end
      end
    end
  end
end
