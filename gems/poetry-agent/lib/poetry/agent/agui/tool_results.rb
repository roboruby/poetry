# frozen_string_literal: true

module Poetry
  module Agent
    module AGUI
      # Pairs tool results with the calls they answer, and puts a result that
      # drifted from its call back beside it. Providers require an
      # assistant's tool call to be followed by its result, and a history
      # sent back as run input must keep that; a MESSAGES_SNAPSHOT that
      # re-ids a streamed result appends its copy after later messages.
      #
      # Positions only, never ids of messages: the history is a list of
      # entries, each `[role, tool_call_id, issued_ids]` - a tool result's
      # call id, or the call ids an assistant message issues, in order.
      #
      # - The anchor of a position is the last entry before it whose role is
      #   not tool, activity or reasoning. A result whose anchor issued an
      #   unanswered call with its id is in place, and answers it.
      # - A result with an earlier unanswered call for its id elsewhere is
      #   detached. Per id, from the last detached result back, each takes
      #   the newest unanswered call issued before it: a provider that
      #   reuses `call_0` every turn keeps each turn's result with its turn.
      # - A result with no earlier call for its id is early. It moves
      #   forward only when its id is on exactly one call in the whole
      #   history and that call is still open; with a reused id, which call
      #   it answers is a guess, and a wrong guess answers a call that may
      #   still be waiting on the user.
      # - Anything else stays where it is, answering nothing: a second
      #   result for an answered call, or one whose call never appears.
      #
      # A moved result goes after its issuer, after the activity and
      # reasoning directly behind it but in front of that reasoning, which
      # belongs to the message after it.
      #
      # @api private
      module ToolResults
        # Roles that neither anchor a result nor separate it from its call.
        TRANSPARENT = %w[activity reasoning].freeze

        module_function

        # The pairing and the repaired order.
        #
        # @param entries [Array<Array(String, String, Array<String>)>] `[role, tool_call_id, issued_ids]`
        # @return [Array(Array<Integer>, Hash{Integer => Array(Integer, Integer)})] the entries'
        #   indices in the repaired order, and each paired result's index to the call it answers:
        #   `[issuer index, n]`, the n-th call with that id the issuer makes
        def pair(entries)
          slots = {}
          detached = Hash.new { |hash, id| hash[id] = [] }
          early = Hash.new { |hash, id| hash[id] = [] }
          links = {}
          anchor = -1
          entries.each_with_index do |(role, call_id, issued), index|
            if role == "tool"
              next unless call_id.is_a?(String)

              opened = slots[call_id]
              next early[call_id] << index unless opened

              in_place = nil
              opened.reverse_each do |slot|
                break unless slot[:issuer] == anchor

                in_place = slot unless slot[:answered]
              end
              if in_place
                in_place[:answered] = true
                links[index] = in_place
              elsif opened.any? { |slot| !slot[:answered] }
                detached[call_id] << index
              end
            elsif !TRANSPARENT.include?(role)
              anchor = index
              seen = Hash.new(0)
              Array(issued).each do |id|
                (slots[id] ||= []) << { issuer: index, n: seen[id], answered: false }
                seen[id] += 1
              end
            end
          end

          owed = Hash.new { |hash, issuer| hash[issuer] = [] }
          move = lambda do |index, slot|
            slot[:answered] = true
            links[index] = slot
            owed[slot[:issuer]] << index
          end
          detached.each do |id, results|
            opened = slots[id]
            cursor = opened.size - 1
            results.reverse_each do |index|
              cursor -= 1 while cursor >= 0 && (opened[cursor][:answered] || opened[cursor][:issuer] >= index)
              break if cursor.negative?

              move.call(index, opened[cursor])
            end
          end
          early.each do |id, results|
            opened = slots[id]
            move.call(results.first, opened.first) if opened&.size == 1 && !opened.first[:answered]
          end

          pairs = links.transform_values { |slot| [slot[:issuer], slot[:n]] }
          return [entries.each_index.to_a, pairs] if owed.empty?

          [reorder(entries, owed.transform_values(&:sort)), pairs]
        end

        # The entries' indices with each moved result after its issuer.
        def reorder(entries, owed)
          moved = owed.values.flatten.to_h { |index| [index, true] }
          order = []
          waiting = nil
          flush = lambda do
            if waiting
              at = order.size
              (order.size - 1).downto(0) do |tail|
                role = entries[order[tail]][0]
                break unless TRANSPARENT.include?(role)

                at = tail if role == "reasoning"
              end
              order.insert(at, *waiting)
            end
            waiting = nil
          end
          entries.each_with_index do |(role, _, _), index|
            next if moved[index]

            flush.call unless role == "tool" || TRANSPARENT.include?(role)
            order << index
            waiting = owed[index] if owed.key?(index)
          end
          flush.call
          order
        end
      end
    end
  end
end
