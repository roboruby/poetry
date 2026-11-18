# frozen_string_literal: true

module Poetry
  module Ui
    # What a reply still being written has left open, closed for display.
    # A reply streams as a growing prefix of its Markdown, and a prefix
    # ends wherever the last token did: inside a bold phrase, inside a
    # code span, halfway through a link's address, one row into a table.
    # Parsed as it stands, each of those shows its raw markers until the
    # closing ones arrive, then jumps. {close} returns the text with the
    # last block's unfinished marks closed (or, where nothing follows an
    # opening mark yet, taken out), so each frame reads as finished prose.
    #
    # Only the last block is touched, since emphasis, code spans and
    # links never cross a blank line, and nothing is touched inside an
    # open code fence, which a parser already reads to the end of the
    # text. The text itself is never altered for the final render: call
    # this while streaming, and render the finished reply as it is.
    #
    # @example
    #   MarkdownTail.close("Ships **tomorr") # => "Ships **tomorr**"
    #   MarkdownTail.close("See [the docs](https://exam") # => "See the docs"
    module MarkdownTail
      # An opening or closing code fence, and what it is made of.
      FENCE = /\A {0,3}(`{3,}|~{3,})/
      # The emphasis marks, by the character they repeat.
      MARKS = { "*" => 3, "_" => 3, "~" => 2 }.freeze
      # What follows "](" in a link still being written: its address, and
      # as much of a quoted title as there is. Anything else is prose
      # that happens to hold "](", and is left alone.
      ADDRESS = /\A\S*(\s+("[^"]*"?|'[^']*'?)?\s*)?\z/
      # What a citation's mark holds between its brackets.
      NUMBER = /\A\d{1,3}\z/
      # A table row that opens with a pipe.
      ROW = /\A\s*\|/
      # A delimiter row, whole or as far as it has been written.
      DELIMITER = /\A\s*\|?[\s:|-]*\z/

      class << self
        # The text with its last block's unfinished marks closed.
        #
        # @param text [String] the Markdown written so far
        # @return [String]
        def close(text)
          text = text.to_s
          head, tail = split(text)
          return text if tail.nil? || tail.strip.empty?

          head + table(inline(tail))
        end

        private

        # The text before its last block, and that block; the block is nil
        # when the text ends inside a code fence.
        def split(text)
          start = 0
          offset = 0
          fence = nil
          text.each_line do |line|
            offset += line.length
            marker = line[FENCE, 1]
            if fence && closes?(line, fence)
              fence = nil
              start = offset
            elsif fence
              next
            elsif marker
              fence = marker
            elsif line.strip.empty?
              start = offset
            end
          end
          fence ? [text, nil] : [text[0, start], text[start..]]
        end

        # Whether a line closes the fence that marker opened.
        def closes?(line, marker)
          closer = line[FENCE, 1]
          closer && closer[0] == marker[0] && closer.length >= marker.length && line.strip == closer
        end

        # The block with its link labels, code span and emphasis settled.
        def inline(block)
          marks(labels(block))
        end

        # A link's label still being written reads as its text: an
        # opening bracket with no closing one yet is taken out, and so is
        # the pair around a label the block ends on, which may be a link
        # whose address has not begun. An image's alt text is left out
        # whole until the image is. A number in brackets is a citation's
        # mark, not a label: whole, it is left as it is, and half written
        # it is left out.
        def labels(block)
          open = []
          last = block.rstrip.length - 1
          outside_code(block).each do |index|
            case block[index]
            when "[" then open << index
            when "]"
              opener = open.pop
              next unless opener && index == last && !block[(opener + 1)...index].match?(NUMBER)

              return labels(unbracketed(block, opener, index))
            end
          end
          return block if open.empty?
          return labels(block[0, open.last]) if block[(open.last + 1)..].strip.match?(NUMBER)

          labels(unbracketed(block, open.last, nil))
        end

        # The positions that are neither escaped nor inside a code span;
        # a code span left open runs to the end.
        def outside_code(block)
          positions = []
          index = 0
          while index < block.length
            if block[index] == "\\"
              index += 2
            elsif block[index] == "`"
              run = block[index..][/\A`+/]
              close_at = block.index(/(?<!`)#{run}(?!`)/, index + run.length)
              break unless close_at

              index = close_at + run.length
            else
              positions << index
              index += 1
            end
          end
          positions
        end

        # The block without a label's brackets, or without the image the
        # label belongs to.
        def unbracketed(block, opener, closer)
          return block[0, opener - 1] if opener.positive? && block[opener - 1] == "!"

          text = block.dup
          text[closer] = "" if closer
          text[opener] = ""
          text
        end

        # The block with its code span, unfinished link and emphasis marks settled.
        def marks(block)
          opened = []
          cuts = []
          index = 0
          while index < block.length
            char = block[index]
            if char == "\\"
              index += 2
            elsif char == "`"
              run = block[index..][/\A`+/]
              close_at = block.index(/(?<!`)#{run}(?!`)/, index + run.length)
              return code_span(block, index, run, opened, cuts) unless close_at

              index = close_at + run.length
            elsif char == "]" && block[index + 1] == "("
              close_at = block.index(")", index + 2)
              return marks(unlinked(block, index)) if close_at.nil? && block[(index + 2)..].match?(ADDRESS)

              index = close_at ? close_at + 1 : index + 1
            elsif MARKS.key?(char)
              run = block[index..][/\A#{Regexp.escape(char)}+/]
              mark(block, index, run, opened, cuts)
              index += run.length
            else
              index += 1
            end
          end
          finish(block, opened, cuts)
        end

        # A code span with no closing run: closed where it stands, or its
        # opening run taken out when nothing follows it yet. The marks
        # opened before it are closed after it. Code that ends in a
        # backtick is set off by a space, or the closing run would grow.
        def code_span(block, index, run, opened, cuts)
          code = block[(index + run.length)..]
          return finish(block[0, index] + code, opened, cuts) if code.strip.empty?

          written = block.rstrip
          finish("#{written}#{" " if written.end_with?("`")}#{run}#{block[written.length..]}", opened, cuts)
        end

        # The block with a link whose address is still being written
        # reduced to its label (an image, to nothing).
        def unlinked(block, bracket)
          opener = block.rindex("[", bracket)
          return block[0, bracket] + block[(bracket + 1)..].delete_prefix("(") if opener.nil?

          label = block[(opener + 1)...bracket]
          image = opener.positive? && block[opener - 1] == "!"
          image ? block[0, opener - 1] : block[0, opener] + label
        end

        # One run of a mark: it closes the nearest opened mark of its kind,
        # or opens one, or is plain text. A run at the very end that does
        # neither is a mark half arrived, and is taken out for now.
        def mark(block, index, run, opened, cuts)
          char = run[0]
          return if run.length > MARKS.fetch(char) || rule?(block, index, run)
          return half_struck(block, index, run, opened, cuts) if char == "~" && run.length == 1

          before = index.zero? ? " " : block[index - 1]
          after = block[index + run.length] || " "
          closes = before !~ /\s/ && !(char == "_" && after =~ /[[:alnum:]]/)
          opens = after !~ /\s/ && !(char == "_" && before =~ /[[:alnum:]]/)
          position = opened.rindex { |entry| entry[:mark] == run } if closes
          if position
            opened.slice!(position..)
          elsif opens
            opened << { mark: run, at: index }
          elsif index + run.length == block.rstrip.length
            half_closed(block, index, run, opened, cuts)
          end
        end

        # One tilde is not a mark, unless it is the first of the two that
        # close a strikethrough, at the very end.
        def half_struck(block, index, run, opened, cuts)
          closing = index + 1 == block.rstrip.length && opened.last&.fetch(:mark) == "~~" && block[index - 1] !~ /\s/
          half_closed(block, index, run, opened, cuts) if closing
        end

        # A thematic break: a line of nothing but three or more of the mark.
        def rule?(block, index, run)
          line_start = (block.rindex("\n", index) || -1) + 1
          line_end = block.index("\n", index) || block.length
          run.length >= 3 && block[line_start...line_end].strip == run
        end

        # A run at the end that is the start of the closing mark (one star
        # of two) completes it; any other is taken out.
        def half_closed(block, index, run, opened, cuts)
          last = opened.last
          if last && last[:mark][0] == run[0] && run.length < last[:mark].length && block[index - 1] !~ /\s/
            opened.pop
            cuts << [block.length, last[:mark][run.length..]]
          else
            cuts << [index, run.length]
          end
        end

        # Applies what the scan decided: the runs to take out, the half
        # closers to complete, then a closer for each mark still open,
        # innermost first, before any trailing whitespace. A mark with
        # nothing after it is taken out instead.
        def finish(block, opened, cuts)
          closers = +""
          opened.reverse_each do |entry|
            rest = block[(entry[:at] + entry[:mark].length)..]
            if rest.strip.empty?
              cuts << [entry[:at], entry[:mark].length]
            else
              closers << entry[:mark]
            end
          end
          additions, removals = cuts.partition { |_at, what| what.is_a?(String) }
          body = block.dup
          removals.sort.reverse_each { |at, length| body[at, length] = "" }
          completed = additions.map(&:last).join
          stripped = body.rstrip
          stripped + completed + closers + body[stripped.length..]
        end

        # A table's first row with no delimiter row under it yet is given
        # one, so the table is a table from its first cell. A row that is
        # only its opening pipe so far is left out until it holds a cell.
        def table(block)
          lines = block.lines
          last = lines.last.to_s
          header = lines[-2].to_s
          if header.match?(ROW) && !lines[-3].to_s.match?(ROW)
            lines[-1] = delimiter_for(header) if last.match?(DELIMITER) && !delimiter?(last, header)
          elsif last.match?(ROW) && cells(last).all?(&:empty?)
            lines.pop
          elsif last.match?(ROW) && !header.match?(ROW)
            lines << "#{"\n" unless last.end_with?("\n")}#{delimiter_for(last)}"
          end
          lines.join
        end

        # Whether a line is a whole delimiter row for that header.
        def delimiter?(line, header)
          cells = cells(line)
          cells.size == cells(header).size && cells.all? { |cell| cell.match?(/\A:?-+:?\z/) }
        end

        # A delimiter row with as many cells as the header has.
        def delimiter_for(header)
          "|#{Array.new([cells(header).size, 1].max, " --- ").join("|")}|\n"
        end

        # A row's cells, without the pipes that open and close it.
        def cells(row)
          row.strip.delete_prefix("|").delete_suffix("|").split(/(?<!\\)\|/, -1).map(&:strip)
        end
      end
    end
  end
end
