# frozen_string_literal: true

module Poetry
  module Ui
    # Sources and the marks that cite them, in the two shapes replies
    # come in. A model told to cite writes numbered marks in its text,
    # "[1]", against sources the host numbered for it. A provider that
    # cites by itself reports spans of the reply, each with the source it
    # rests on. {mark} turns the second shape into the first, which is the
    # one poetry_markdown reads; {sources} gives either list one shape.
    #
    # @example Spans a provider reported
    #   text, sources = Poetry::Ui::Citations.mark(message.content, message.citations)
    #   poetry_markdown(text: text, sources: sources)
    module Citations
      class << self
        # The text with a numbered mark after each cited span, and the
        # sources in the order the reply first cites them. A source cited
        # twice keeps its number. A citation that names no span still
        # brings its source.
        #
        # @param text [String] the reply
        # @param citations [Array] each answers (or holds) url, title,
        #   cited_text and end_index, as RubyLLM's citations do
        # @return [Array(String, Array<Hash>)]
        def mark(text, citations)
          text = text.to_s
          listed = []
          marks = Array(citations).filter_map do |citation|
            source = source(citation) or next
            number = (listed.index { |known| same?(known, source) } || (listed.push(source).size - 1)) + 1
            position = read(citation, :end_index)
            [position, number] if position.is_a?(Integer) && position.between?(0, text.length)
          end
          marked = text.dup
          marks.uniq.sort_by { |position, number| [-position, -number] }
               .each { |position, number| marked.insert(position, "[#{number}]") }
          [marked, listed]
        end

        # A list of sources in one shape: a hash each, with :title, :href
        # and :description, whatever they were given as. Entries with
        # neither a title nor an address are left out.
        #
        # @param list [Array] hashes (title, href or url, description or
        #   cited_text) or objects answering those
        # @return [Array<Hash>]
        def sources(list)
          Array(list).filter_map { |entry| source(entry) }
        end

        private

        # One source in the common shape, or nil when it names nothing.
        def source(entry)
          title = read(entry, :title).to_s.strip
          href = (read(entry, :href) || read(entry, :url)).to_s.strip
          return if title.empty? && href.empty?

          description = (read(entry, :description) || read(entry, :cited_text)).to_s.strip
          { title: title.presence || href, href: href.presence, description: description.presence }
        end

        # Whether two entries name one source: by address, or by title when neither has one.
        def same?(known, source)
          known[:href] || source[:href] ? known[:href] == source[:href] : known[:title] == source[:title]
        end

        # A value by name, from a hash with either kind of key or from an object.
        def read(entry, name)
          if entry.is_a?(Hash)
            entry.key?(name) ? entry[name] : entry[name.to_s]
          elsif entry.respond_to?(name)
            entry.public_send(name)
          end
        end
      end
    end
  end
end
