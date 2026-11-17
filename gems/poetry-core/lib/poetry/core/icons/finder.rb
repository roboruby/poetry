# frozen_string_literal: true

module Poetry
  module Core
    module Icons
      # Answers "which icon means this". A name says what an icon draws
      # (trash, circle-alert); the words its set files it under say what
      # it is used for (delete, warning), and that is how an icon is asked
      # for. The finder ranks a set's icons against a description by all
      # three things it knows: the names, the names they used to have, and
      # those words.
      #
      # A set without tags is still searched by name, so "arrow left"
      # finds arrow-left in any set; only the search by meaning needs them.
      #
      # @example
      #   finder = Icons::Finder.new(names: set.names, aliases: set.aliases, tags: set.tags)
      #   finder.find("delete").first
      #   # => { name: "delete", score: 18, answers: ["delete"], tags: ["backspace", "remove"] }
      class Finder
        # Words in a description that say nothing about the icon.
        FILLER = %w[a an the icon icons for of to with and or in on that this which means meaning is as].freeze
        # What a word of the description is worth where it is found whole.
        WEIGHTS = { name: 6, tag: 4, former: 3 }.freeze
        # How many icons an answer holds unless told otherwise, and at most.
        LIMIT = 8
        # The most icons one answer may hold.
        CEILING = 50

        # A finder over one set: its names, the names they replaced and its tags.
        #
        # @param names [Enumerable<Symbol, String>] the set's current names
        # @param aliases [Hash{String => String}] a former name => the name it renders as
        # @param tags [Hash{String => Array<String>}] a name => the words it is filed under
        # @param hint [String, nil] what the set says it does not draw, and where that is
        def initialize(names:, aliases: {}, tags: {}, hint: nil)
          @hint = hint
          former = aliases.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(old, current), map|
            map[current.to_s].concat(words(old))
          end
          @entries = names.map do |name|
            name = name.to_s
            filed = Array(tags[name]).map(&:to_s)
            { name: name, places: { name: words(name), tag: filed.flat_map { |tag| words(tag) }.uniq,
                                    former: former.fetch(name, []).uniq }, tags: filed }
          end
        end

        # The icons that answer a description, best first: the ones that
        # answer the most of its words, then the better answers, then the
        # plainer name (trash before bookmark-minus for "delete"), then
        # the icon that lists the word earliest among its tags, since a
        # set lists an icon's main use first.
        #
        # A word in a name counts for as much of the name as the
        # description covers: "warning" is all of what a warning icon is
        # and half of battery-warning, which is a battery.
        #
        # @param query [String] what the icon should mean, or part of its name
        # @param limit [Integer] the most icons to return (1 to 50)
        # @return [Array<Hash>] each `{ name:, score:, answers:, tags: }`:
        #   the name, its score, the words of the description it answered,
        #   and the words it is filed under, the ones that answered first
        def find(query, limit: LIMIT)
          asked = words(query) - FILLER
          return [] if asked.empty?

          joined = asked.join("-")
          ranked = @entries.filter_map { |entry| rank(entry, asked, joined) }
          ranked.sort_by! do |match|
            [-match[:answers].size, -match[:score], match[:name].count("-"), match.delete(:filed), match[:name]]
          end
          ranked.first(limit.to_i.clamp(1, CEILING))
        end

        # What the set says about what it does not draw (Lucide: brand
        # marks), or nil.
        #
        # @return [String, nil]
        attr_reader :hint

        # What to say when a word is no icon's name: the icons to try
        # instead (the ones with the word in their name first, then the
        # ones filed under it), or, when there is none, the set's own note
        # on what it does not draw. An unknown name is most often a meaning
        # written as a name (`:dashboard`) or a brand (`:github`), and this
        # is the way out.
        #
        # @param word [Symbol, String] the name that was asked for
        # @return [String] the advice, empty when there is none
        # @example
        #   finder.advice(:dashboard) # => 'try :"layout-dashboard", :gauge, :engine'
        #   finder.advice(:github)    # => "Lucide draws no brand marks ..."
        def advice(word)
          asked = words(word)
          named, filed = find(asked.join(" "), limit: 6).partition { |match| words(match[:name]).intersect?(asked) }
          picks = (named + filed).first(3).map { |match| match[:name].to_sym.inspect }
          picks.any? ? "try #{picks.join(", ")}" : hint.to_s
        end

        # A short name: the default would print every icon's words.
        #
        # @return [String]
        def inspect
          "#<#{self.class.name} #{@entries.size} icons>"
        end

        private

        # One icon against the description: nil when it answers no word.
        def rank(entry, asked, joined)
          places = entry[:places]
          covered = places[:name].count { |part| asked.any? { |word| word == part || close?(word, part) } }
          weights = WEIGHTS.merge(name: WEIGHTS[:name] * covered / [places[:name].size, 1].max)
          answers = []
          score = asked.sum do |word|
            worth = worth(places, weights, word)
            answers << word if worth.positive?
            worth
          end
          return nil if answers.empty?

          score += WEIGHTS[:name] * 2 if entry[:name] == joined
          hit, rest = entry[:tags].partition { |tag| words(tag).intersect?(answers) }
          { name: entry[:name], score: score, answers: answers, tags: hit + rest, filed: filed(entry[:tags], asked) }
        end

        # What one word is worth to one icon: the best place it is found
        # whole, or half that for a word close to one there.
        def worth(places, weights, word)
          weights.map do |place, weight|
            found = places.fetch(place)
            if found.include?(word) then weight
            elsif found.any? { |other| close?(word, other) } then weight / 2
            else 0
            end
          end.max
        end

        # How early the icon's tags hold a word of the description: the
        # position of the first tag that does. An icon found by its name
        # alone has no tag to place, and counts as first.
        def filed(tags, asked)
          tags.index { |tag| words(tag).intersect?(asked) } || 0
        end

        # Two forms of one word (delete and deletion, arrow and arrows):
        # they share their first four letters or more, and differ by a
        # short ending.
        def close?(word, other)
          shared = 0
          shared += 1 while shared < word.length && word[shared] == other[shared]
          shared >= 4 && shared >= [word.length, other.length].max - 3
        end

        # A name, tag or description as its words.
        def words(text)
          text.to_s.downcase.scan(/[a-z0-9]+/)
        end
      end
    end
  end
end
