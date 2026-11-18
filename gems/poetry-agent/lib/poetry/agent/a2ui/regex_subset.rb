# frozen_string_literal: true

module Poetry
  module Agent
    module A2UI
      # The A2UI regex dialect: the portable subset of ECMAScript pattern
      # syntax (Unicode mode, no flags) the protocol defines for `regex`,
      # with the static safety check it runs before any matching. A pattern
      # is parsed here and never handed raw to Ruby's engine: the tree
      # answers the safety rules, then is written out as the Ruby
      # expression that matches the same values (`^` and `$` as the ends of
      # the value, ASCII `\d`, `\w` and `\b`, ECMAScript's `\s` and `.`).
      #
      # A refused pattern raises {Rejected}, whose message opens with one
      # of the protocol's tokens: `PATTERN_TOO_LONG`, `UNSUPPORTED_SYNTAX`,
      # `NESTED_QUANTIFIER`, `OVERLAPPING_ALTERNATION`, `ADJACENT_OVERLAP`.
      #
      # @example
      #   RegexSubset.match?("^[a-z]+@[a-z]+\\.com$", "ada@example.com") # => true
      #   RegexSubset.match?("^abc$", "abc\n")                           # => false
      #   RegexSubset.compile("(a+)+$") # raises RegexSubset::Rejected, "NESTED_QUANTIFIER: ..."
      module RegexSubset
        # The longest pattern, in code points.
        MAX_PATTERN = 256
        # The longest value a pattern is matched against, in code points; a longer one does not match.
        MAX_VALUE = 4096
        # The largest count a `{n,m}` quantifier may name.
        MAX_BOUND = 65_535
        # How long one match may run, in seconds: the engine's own limit, behind the static check.
        TIMEOUT = 0.05
        # How many compiled patterns are kept.
        CACHE_SIZE = 256

        # A pattern the dialect or its safety check refuses.
        class Rejected < StandardError
          # The refusal's token.
          #
          # @return [String] the protocol's token for the refusal
          attr_reader :token

          # A refusal by its token.
          #
          # @param token [String] which refusal this is, `NESTED_QUANTIFIER` for one
          # @param detail [String] what was refused
          def initialize(token, detail)
            @token = token
            super("#{token}: #{detail}")
          end
        end

        # A set of code points, as sorted ranges that neither touch nor overlap.
        Chars = Data.define(:ranges)
        # A group, capturing or not: the dialect has no backreferences, so the two read alike.
        Group = Data.define(:child)
        # A lookahead, `(?=...)` or `(?!...)`.
        Look = Data.define(:child, :negated)
        # A zero-width assertion: `:start`, `:end`, `:boundary` or `:not_boundary`.
        Anchor = Data.define(:kind)
        # A sequence; the empty sequence matches the empty string.
        Concat = Data.define(:items)
        # An alternation.
        Alt = Data.define(:branches)
        # A quantified atom; `max` is nil when unbounded.
        Repeat = Data.define(:child, :min, :max, :lazy)

        @cache = {}
        @lock = Mutex.new

        module_function

        # Whether the pattern matches anywhere in the value. A value past
        # {MAX_VALUE} code points does not match, and neither does one the
        # engine's time limit stops.
        #
        # @param pattern [String] a pattern in the dialect
        # @param value [String] the value searched
        # @return [Boolean]
        # @raise [Rejected] for a pattern outside the dialect or one the safety check refuses
        # @raise [Regexp::TimeoutError] when a match outruns {TIMEOUT}
        def match?(pattern, value)
          expression = compile(pattern)
          value.length <= MAX_VALUE && expression.match?(value)
        end

        # The Ruby expression for a pattern, checked first.
        #
        # @param pattern [String] a pattern in the dialect
        # @return [Regexp]
        # @raise [Rejected] for a pattern outside the dialect or one the safety check refuses
        def compile(pattern)
          held = @lock.synchronize { @cache[pattern] }
          return held if held

          expression = Regexp.new(Writer.source(check(pattern)), timeout: TIMEOUT)
          @lock.synchronize do
            @cache.shift if @cache.size >= CACHE_SIZE
            @cache[pattern.dup.freeze] = expression
          end
        end

        # The HTML `pattern` attribute that holds an input to a pattern in
        # the browser's own constraint validation. The attribute wants the
        # whole value matched where the dialect searches, so the pattern
        # sits between two runs of anything.
        #
        # @param pattern [String] a pattern in the dialect
        # @return [String, nil] the attribute's value, or nil for a pattern the dialect or its
        #   safety check refuses (an input never carries one of those)
        def native(pattern)
          "[\\s\\S]*(?:#{Native.source(check(pattern))})[\\s\\S]*"
        rescue Rejected
          nil
        end

        # A pattern's tree once the dialect and the four safety rules have passed.
        #
        # @param pattern [String]
        # @return [Object] the tree's root node
        # @raise [Rejected]
        # @api private
        def check(pattern)
          unless pattern.encoding == Encoding::UTF_8 && pattern.valid_encoding?
            raise Rejected.new("UNSUPPORTED_SYNTAX", "the pattern is not valid UTF-8")
          end
          if pattern.length > MAX_PATTERN
            raise Rejected.new("PATTERN_TOO_LONG", "#{pattern.length} code points, over #{MAX_PATTERN}")
          end

          Parser.new(pattern).parse.tap { |tree| Safety.check(tree) }
        end

        # Code point ranges as plain `[low, high]` pairs.
        # @api private
        module Ranges
          # The last code point.
          LAST = 0x10FFFF
          # The surrogates, which no well-formed value holds.
          SURROGATES = [0xD800, 0xDFFF].freeze

          module_function

          # Sorted, merged, and with the surrogates cut out.
          def normalize(ranges)
            merged = ranges.sort.each_with_object([]) do |(low, high), list|
              if list.any? && low <= list.last[1] + 1
                list.last[1] = [list.last[1], high].max
              else
                list << [low, high]
              end
            end
            merged.flat_map { |range| without_surrogates(range) }
          end

          # Every code point the ranges leave out.
          def complement(ranges)
            gaps = []
            from = 0
            ranges.each do |low, high|
              gaps << [from, low - 1] if low > from
              from = high + 1
            end
            gaps << [from, LAST] if from <= LAST
            normalize(gaps)
          end

          # Whether two normalized lists share a code point.
          def overlap?(left, right)
            left.any? { |low, high| right.any? { |other_low, other_high| low <= other_high && other_low <= high } }
          end

          # A range's parts on either side of the surrogates.
          def without_surrogates((low, high))
            first, last = SURROGATES
            return [[low, high]] if high < first || low > last

            [([low, first - 1] if low < first), ([last + 1, high] if high > last)].compact
          end
        end

        # `\d`.
        DIGIT = [[0x30, 0x39]].freeze
        # `\w`.
        WORD = [[0x30, 0x39], [0x41, 0x5A], [0x5F, 0x5F], [0x61, 0x7A]].freeze
        # `\s`: ECMAScript's WhiteSpace and LineTerminator.
        SPACE = [[0x09, 0x0D], [0x20, 0x20], [0xA0, 0xA0], [0x1680, 0x1680], [0x2000, 0x200A], [0x2028, 0x2029],
                 [0x202F, 0x202F], [0x205F, 0x205F], [0x3000, 0x3000], [0xFEFF, 0xFEFF]].freeze
        # What `.` leaves out: the line terminators.
        LINE_ENDS = [[0x0A, 0x0A], [0x0D, 0x0D], [0x2028, 0x2029]].freeze
        # The class escapes, by letter.
        CLASSES = { "d" => DIGIT, "D" => Ranges.complement(DIGIT), "w" => WORD, "W" => Ranges.complement(WORD),
                    "s" => SPACE, "S" => Ranges.complement(SPACE) }.freeze
        # `.`.
        DOT = Ranges.complement(LINE_ENDS).freeze
        # The control escapes, by letter.
        CONTROLS = { "t" => 0x09, "n" => 0x0A, "v" => 0x0B, "f" => 0x0C, "r" => 0x0D }.freeze
        # The characters an identity escape may name.
        SYNTAX = %w[^ $ \\ . * + ? ( ) [ ] { } | /].freeze

        # The dialect's parser: one pattern to its tree, or {Rejected}.
        # @api private
        class Parser
          # A parser over one pattern.
          #
          # @param pattern [String] valid UTF-8
          def initialize(pattern)
            @chars = pattern.chars
            @at = 0
          end

          # Parses the whole pattern.
          #
          # @return [Object] the tree's root node
          # @raise [Rejected]
          def parse
            tree = disjunction
            refuse("an unmatched closing parenthesis") unless eof?
            tree
          end

          private

          # Whether the pattern is used up.
          def eof? = @at >= @chars.size
          # The character at the cursor, or one further on, without taking it.
          def peek(ahead = 0) = @chars[@at + ahead]

          # Takes the character at the cursor; a pattern that ends there is refused.
          def take
            refuse("the pattern ends early") if eof?
            @chars[@at].tap { @at += 1 }
          end

          # Takes the character at the cursor when it is the one given.
          def eat?(char)
            return false unless peek == char

            @at += 1
            true
          end

          # Refuses the pattern as outside the dialect.
          def refuse(detail) = raise(Rejected.new("UNSUPPORTED_SYNTAX", detail))

          # Branches separated by `|`.
          def disjunction
            branches = [alternative]
            branches << alternative while eat?("|")
            branches.size == 1 ? branches.first : Alt.new(branches: branches)
          end

          # One branch: its terms in sequence (a lone term stands for itself).
          def alternative
            items = []
            items << term until eof? || ["|", ")"].include?(peek)
            items.size == 1 ? items.first : Concat.new(items: items)
          end

          # An atom with the quantifier that follows it, if one does.
          def term
            node = atom
            return node unless quantifier?(peek)

            refuse("a quantifier on an assertion") if node.is_a?(Anchor) || node.is_a?(Look)
            quantifier(node)
          end

          # Whether a character opens a quantifier.
          def quantifier?(char) = ["*", "+", "?", "{"].include?(char)

          # One atom: an assertion, a set, a group, or a literal character.
          def atom
            char = take
            case char
            when "^" then Anchor.new(kind: :start)
            when "$" then Anchor.new(kind: :end)
            when "." then Chars.new(ranges: DOT)
            when "[" then char_class
            when "(" then group
            when "\\" then escaped_atom
            when "{", "}", "]" then refuse("an unescaped #{char}")
            when "*", "+", "?" then refuse("nothing to repeat before #{char}")
            else single(char.ord)
            end
          end

          # The set of one code point.
          def single(code) = Chars.new(ranges: [[code, code]])

          # A group after its opening parenthesis: capturing, non-capturing, or a lookahead.
          def group
            unless eat?("?")
              body = disjunction
              refuse("an unclosed group") unless eat?(")")
              return Group.new(child: body)
            end
            kind = take
            refuse("the group extension (?#{kind}") unless [":", "=", "!"].include?(kind)
            body = disjunction
            refuse("an unclosed group") unless eat?(")")
            kind == ":" ? Group.new(child: body) : Look.new(child: body, negated: kind == "!")
          end

          # The atom an escape outside a class stands for.
          def escaped_atom
            kind, value = escape(in_class: false)
            case kind
            when :anchor then Anchor.new(kind: value)
            when :ranges then Chars.new(ranges: value)
            else single(value)
            end
          end

          # An escape after its backslash: `[:single, code]`, `[:ranges, list]` or `[:anchor, kind]`.
          def escape(in_class:)
            char = take
            return boundary(char, in_class) if %w[b B].include?(char)
            return [:ranges, CLASSES[char]] if CLASSES.key?(char)
            return [:single, CONTROLS[char]] if CONTROLS.key?(char)
            return [:single, numeric(char)] if char.match?(/[0-9xu]/)
            return [:single, char.ord] if SYNTAX.include?(char) || (in_class && char == "-")

            refuse("the escape \\#{char}")
          end

          # `\b` and `\B`: word boundaries outside a class, a backspace (and a refusal) inside one.
          def boundary(char, in_class)
            return [:anchor, char == "b" ? :boundary : :not_boundary] unless in_class

            char == "b" ? [:single, 0x08] : refuse("\\B inside a character class")
          end

          # The code point of a `\0`, `\xHH`, `\uHHHH` or `\u{...}` escape; a backreference is refused.
          def numeric(char)
            case char
            when "0" then peek&.match?(/[0-9]/) ? refuse("an octal escape") : 0
            when "x" then hex(2)
            when "u" then eat?("{") ? braced_hex : scalar(hex(4))
            else refuse("a backreference")
            end
          end

          # A fixed run of hexadecimal digits as a number.
          def hex(digits)
            text = Array.new(digits) { take }.join
            text.match?(/\A\h+\z/) ? text.to_i(16) : refuse("a malformed hexadecimal escape")
          end

          # The code point of a `\u{...}` escape after its opening brace.
          def braced_hex
            text = +""
            text << take until eof? || peek == "}"
            refuse("a malformed \\u{...} escape") unless eat?("}") && text.match?(/\A\h+\z/)
            refuse("a \\u{...} escape past U+10FFFF") if text.sub(/\A0+/, "").length > 6 || text.to_i(16) > Ranges::LAST
            scalar(text.to_i(16))
          end

          # A code point that is not a surrogate, which the dialect refuses.
          def scalar(code)
            first, last = Ranges::SURROGATES
            code.between?(first, last) ? refuse("a surrogate escape") : code
          end

          # A character class after its opening bracket.
          def char_class
            negated = eat?("^")
            ranges = []
            ranges.concat(class_item) until eof? || peek == "]"
            refuse("an unclosed character class") unless eat?("]")
            refuse("an empty character class") if ranges.empty?
            set = Ranges.normalize(ranges)
            Chars.new(ranges: negated ? Ranges.complement(set) : set)
          end

          # One member of a class, or the range two of them make.
          def class_item
            low, ranges = class_atom
            return ranges unless peek == "-" && peek(1) != "]"

            take
            refuse("character class subtraction") if peek == "-"
            high, = class_atom
            refuse("a class escape as the end of a range") unless low && high
            refuse("a character class range out of order") if low > high
            [[low, high]]
          end

          # One member of a class: its code point (nil for a class escape) and its ranges.
          def class_atom
            if eat?("\\")
              kind, value = escape(in_class: true)
              return kind == :single ? [value, [[value, value]]] : [nil, value]
            end
            refuse("a nested character class") if peek == "["
            refuse("character class intersection") if peek == "&" && peek(1) == "&"
            code = take.ord
            [code, [[code, code]]]
          end

          # The quantifier at the cursor, over the atom before it.
          def quantifier(child)
            min, max = bounds(take)
            lazy = eat?("?")
            refuse("a chained or possessive quantifier") if quantifier?(peek)
            Repeat.new(child: child, min: min, max: max, lazy: lazy)
          end

          # A quantifier's least and most (nil for unbounded).
          def bounds(char)
            case char
            when "*" then [0, nil]
            when "+" then [1, nil]
            when "?" then [0, 1]
            else braced_bounds
            end
          end

          # The bounds of a `{n}`, `{n,}` or `{n,m}` quantifier after its opening brace.
          def braced_bounds
            min = count
            return [min, min] if eat?("}")

            refuse("a malformed {n,m} quantifier") unless eat?(",")
            return [min, nil] if eat?("}")

            max = count
            refuse("a malformed {n,m} quantifier") unless eat?("}")
            refuse("a quantifier whose minimum exceeds its maximum") if max < min
            [min, max]
          end

          # A decimal count inside a braced quantifier.
          def count
            digits = +""
            digits << take while peek&.match?(/[0-9]/)
            refuse("a malformed {n,m} quantifier") if digits.empty?
            refuse("a quantifier bound over #{MAX_BOUND}") if digits.length > 5 || digits.to_i > MAX_BOUND
            digits.to_i
          end
        end

        # The static safety check: the three rules a tree answers (the
        # pattern's length is the first, checked before it is parsed).
        # @api private
        module Safety
          module_function

          # Refuses a tree that breaks a rule.
          #
          # @param tree [Object] the tree's root node
          # @raise [Rejected] for the first rule the tree breaks
          def check(tree)
            if any?(tree) { |node| nested_quantifier?(node) }
              raise Rejected.new("NESTED_QUANTIFIER", "a quantifier that repeats more than once holds an unbounded one")
            end
            if any?(tree) { |node| overlapping_alternation?(node) }
              raise Rejected.new("OVERLAPPING_ALTERNATION",
                                 "an unbounded quantifier repeats branches that can start alike")
            end
            return unless any?(tree) { |node| adjacent_overlap?(node) }

            raise Rejected.new("ADJACENT_OVERLAP", "two unbounded quantifiers side by side can match one character")
          end

          # Whether the node or any node under it answers the block.
          def any?(node, &)
            yield(node) || children(node).any? { |child| any?(child, &) }
          end

          # A node's children, lookahead bodies among them.
          def children(node)
            case node
            when Group, Look, Repeat then [node.child]
            when Concat then node.items
            when Alt then node.branches
            else []
            end
          end

          # The node under its groups.
          def unwrap(node)
            node = node.child while node.is_a?(Group)
            node
          end

          # Whether a node is a quantifier without an upper bound.
          def unbounded?(node) = node.is_a?(Repeat) && node.max.nil?

          # Rule 2: a quantifier above one over a subexpression with an unbounded quantifier.
          def nested_quantifier?(node)
            node.is_a?(Repeat) && (node.max.nil? || node.max > 1) && any?(node.child) { |inner| unbounded?(inner) }
          end

          # Rule 3: an unbounded quantifier over an alternation whose branches can start alike.
          def overlapping_alternation?(node)
            return false unless unbounded?(node)

            inner = unwrap(node.child)
            return false unless inner.is_a?(Alt)

            starts = inner.branches.map { |branch| first(unwrap(branch)) }
            starts.combination(2).any? { |left, right| Ranges.overlap?(left, right) }
          end

          # Rule 4: two unbounded atoms that share a character, with nothing between them that must match.
          def adjacent_overlap?(node)
            return false unless node.is_a?(Concat)

            node.items.each_with_index.any? do |item, index|
              head = unwrap(item)
              unbounded?(head) && followed_by_overlap?(chars(head.child), node.items.drop(index + 1))
            end
          end

          # Whether an unbounded atom sharing a character with the set follows before anything that must match.
          def followed_by_overlap?(set, tail)
            tail.each do |item|
              following = unwrap(item)
              return true if unbounded?(following) && Ranges.overlap?(set, chars(following.child))
              return false unless nullable?(item)
            end
            false
          end

          # Whether the node can match the empty string.
          def nullable?(node)
            case node
            when Anchor, Look then true
            when Chars then false
            when Repeat then node.min.zero? || nullable?(node.child)
            when Alt then node.branches.any? { |branch| nullable?(branch) }
            else children(node).all? { |child| nullable?(child) }
            end
          end

          # The code points a match of the node can start with.
          def first(node)
            case node
            when Chars then node.ranges
            when Group then first(node.child)
            when Repeat then node.max&.zero? ? [] : first(node.child)
            when Alt then Ranges.normalize(node.branches.flat_map { |branch| first(branch) })
            when Concat then first_of_sequence(node.items)
            else []
            end
          end

          # The starts of a sequence: each item's, up to the first that cannot be empty.
          def first_of_sequence(items)
            sets = []
            items.each do |item|
              sets.concat(first(item))
              break unless nullable?(item)
            end
            Ranges.normalize(sets)
          end

          # Every code point the node can consume, lookaheads apart.
          def chars(node)
            case node
            when Chars then node.ranges
            when Look, Anchor then []
            when Repeat then node.max&.zero? ? [] : chars(node.child)
            else Ranges.normalize(children(node).flat_map { |child| chars(child) })
            end
          end
        end

        # Writes a checked tree as ECMAScript pattern source the HTML
        # `pattern` attribute takes (it compiles under the `v` flag): the
        # dialect's own spelling, with a class written out as escaped code
        # points so no character of it reads as syntax there.
        # @api private
        module Native
          # The dialect's sets that have a spelling of their own.
          NAMED = { DOT => ".", **CLASSES.to_h { |letter, ranges| [ranges, "\\#{letter}"] } }.freeze
          # The assertions, by kind.
          ANCHORS = { start: "^", end: "$", boundary: "\\b", not_boundary: "\\B" }.freeze
          # A character that stands for itself outside a class.
          PLAIN = %r{\A[!-~&&[^\^$\\.*+?()\[\]{}|/]]\z}

          module_function

          # A node as ECMAScript pattern source.
          #
          # @param node [Object] a node of a checked tree
          # @return [String]
          def source(node)
            case node
            when Chars then char_set(node.ranges)
            when Anchor then ANCHORS.fetch(node.kind)
            when Group then "(?:#{source(node.child)})"
            when Look then "(?#{node.negated ? "!" : "="}#{source(node.child)})"
            when Concat then node.items.map { |item| source(item) }.join
            when Alt then node.branches.map { |branch| source(branch) }.join("|")
            else "#{source(node.child)}#{Writer.quantifier(node.with(lazy: false))}#{"?" if node.lazy}"
            end
          end

          # A set by its own spelling, as one character, or as a class of escaped code points.
          def char_set(ranges)
            return NAMED[ranges] if NAMED.key?(ranges)
            return "(?:(?!))" if ranges.empty?
            return literal(ranges.first.first) if ranges.one? && ranges.first.uniq.one?

            "[#{ranges.map { |low, high| low == high ? escape(low) : "#{escape(low)}-#{escape(high)}" }.join}]"
          end

          # One code point outside a class: itself when it is plain, escaped otherwise.
          def literal(code)
            char = [code].pack("U")
            char.match?(PLAIN) ? char : escape(code)
          end

          # A code point as an escape.
          def escape(code) = format("\\u{%X}", code)
        end

        # Writes a checked tree as the Ruby expression that matches the same values.
        # @api private
        module Writer
          # The ASCII word class, for the boundaries.
          WORD_CLASS = "[0-9A-Za-z_]"
          # The assertions, by kind: the ends of the value and the ASCII word boundaries.
          ANCHORS = {
            start: "\\A", end: "\\z",
            boundary: "(?:(?<=#{WORD_CLASS})(?!#{WORD_CLASS})|(?<!#{WORD_CLASS})(?=#{WORD_CLASS}))",
            not_boundary: "(?:(?<=#{WORD_CLASS})(?=#{WORD_CLASS})|(?<!#{WORD_CLASS})(?!#{WORD_CLASS}))"
          }.freeze

          module_function

          # A node as Ruby regular expression source.
          #
          # @param node [Object] a node of a checked tree
          # @return [String] Ruby regular expression source
          def source(node)
            case node
            when Chars then char_set(node.ranges)
            when Anchor then ANCHORS.fetch(node.kind)
            when Group then group(node.child)
            when Look then "(?#{node.negated ? "!" : "="}#{source(node.child)})"
            when Concat then node.items.map { |item| source(item) }.join
            when Alt then node.branches.map { |branch| source(branch) }.join("|")
            else "#{source(node.child)}#{quantifier(node)}"
            end
          end

          # A group, without captures. One that holds a lone quantified atom
          # closes on an empty group, so a quantifier on the group stays a
          # quantifier on a group (Ruby folds `(?:a+)?` into `a*` and warns).
          def group(child)
            lone = child
            lone = lone.child while lone.is_a?(Group)
            "(?:#{source(child)}#{"(?:)" if lone.is_a?(Repeat)})"
          end

          # A set as a class of escaped code points; a set of none matches nothing.
          def char_set(ranges)
            return "(?:(?!))" if ranges.empty?
            return escape(ranges.first.first) if ranges.one? && ranges.first.uniq.one?

            "[#{ranges.map { |low, high| low == high ? escape(low) : "#{escape(low)}-#{escape(high)}" }.join}]"
          end

          # A code point as an escape Ruby reads literally.
          def escape(code) = format("\\u{%X}", code)

          # The quantifier's text. An exact count takes no lazy mark: Ruby
          # reads `{n}?` as an optional `{n}`.
          def quantifier(node)
            text = case node
                   in { min: 0, max: nil } then "*"
                   in { min: 1, max: nil } then "+"
                   in { min: 0, max: 1 } then "?"
                   else braces(node.min, node.max)
                   end
            node.lazy && node.min != node.max ? "#{text}?" : text
          end

          # A counted quantifier's text.
          def braces(min, max)
            return "{#{min}}" if min == max

            "{#{min},#{max}}"
          end
        end
      end
    end
  end
end
