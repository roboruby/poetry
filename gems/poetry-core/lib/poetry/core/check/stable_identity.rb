# frozen_string_literal: true

module Poetry
  module Core
    module Check
      # The StableId heuristics: two WARNING-severity rules over
      # raw ERB text, each catching a render that escapes the per-request
      # id story and therefore needs explicit identity (key: or id:).
      #
      # HEURISTIC, by design and by documentation: block extents are
      # matched by scanning scriptlet openers/closers, which covers
      # conventional ERB and misses exotic structure; cross-template
      # composition (a cached partial rendering components defined
      # elsewhere) is invisible to any static check - the dev-mode
      # composed-DOM tripwire is the runtime complement.
      #
      # - stable-identity/cache: a poetry component inside a `<% cache %>`
      #   block without key:/id: freezes a random id into the fragment;
      #   replays can collide and morphs can't pair it.
      # - stable-identity/collection: a poetry component inside an
      #   each/map loop without key:/id: gets a fresh random id per
      #   render, so Turbo morph replaces it on any reorder instead of
      #   following the record.
      #
      # @api private
      class StableIdentity
        # Decorative/id-less helpers where the warnings would be noise.
        SKIP_HELPERS = %w[
          poetry_icon poetry_separator poetry_skeleton poetry_kbd poetry_badge
          poetry_label poetry_spinner poetry_typeset poetry_link poetry_empty
        ].freeze

        # A scriptlet that OPENS a Ruby block (needs its own <% end %>):
        # trailing `do |...|`, or a non-modifier if/unless/case/begin.
        BLOCK_OPENER =
          /(?:\bdo\s*(?:\|[^|]*\|)?\s*\z)|(?:\A\s*(?:if|unless|case|while|until|for|begin)\b)/
        CACHE_OPENER = /\A\s*cache[\s(]/
        LOOP_OPENER =
          /\.(?:each|each_with_index|each_with_object|each_slice|map|collect|flat_map)\b.*\bdo\b|\Afor\s.+\sin\s/
        IDENTITY_ARG = /(?:\bkey:|\bid:|["']key["']\s*=>|["']id["']\s*=>)/

        def initialize(catalog)
          @catalog = catalog
        end

        # Returns [Finding] for one ERB source. Tracks a stack of open
        # blocks (tagged cache/loop/other) and flags poetry helper calls
        # rendered while a cache or loop frame is open.
        def lint(source)
          findings = []
          stack = []

          source.each_line.with_index(1) do |line, number|
            line.scan(/<%(?:=|-)?\s*(.*?)\s*(?:-)?%>/m).each do |(code)|
              next if code.nil?

              flag_helpers(code, number, stack, findings)

              if code.match?(/\A\s*end\b/)
                stack.pop
              elsif code.match?(BLOCK_OPENER)
                stack << frame_for(code)
              end
            end
          end

          findings
        end

        private

        def frame_for(code)
          return :cache if code.match?(CACHE_OPENER)
          return :loop if code.match?(LOOP_OPENER)

          :other
        end

        def flag_helpers(code, line, stack, findings)
          code.scan(/\b(poetry_[a-z0-9_]+)\b/) do |(helper)|
            next unless @catalog.helper?(helper)
            next if SKIP_HELPERS.include?(helper)
            next if code.match?(IDENTITY_ARG)

            if stack.include?(:cache)
              findings << Finding.new(
                rule: "stable-identity/cache", severity: :warning, line: line,
                message: "#{helper} inside a cache block without key:/id: freezes a random id " \
                         "into the fragment - replays can collide and Turbo morph can't pair it " \
                         "(heuristic: block extents are scanned, not parsed)"
              )
            elsif stack.include?(:loop)
              findings << Finding.new(
                rule: "stable-identity/collection", severity: :warning, line: line,
                message: "#{helper} inside a collection loop without key:/id: re-randomizes " \
                         "per render - a Turbo morph reorder replaces it instead of following " \
                         "the record; pass key: record (heuristic)"
              )
            end
          end
        end
      end
    end
  end
end
