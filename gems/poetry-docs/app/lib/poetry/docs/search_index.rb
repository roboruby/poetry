# The docs search index: every catalog page rendered through an
# integration session, headings extracted from the SAME rendered truth the
# gallery gates walk, committed at public/search-index.json. The palette
# server-renders the heading entries as its Reference group - no client
# fetch, no external indexer, no Node. Regenerate: bin/rails docs:search_index
# (the freshness test fails with that instruction when the file drifts).
#
# @example Rebuild the committed index
#   SearchIndex.write! # => number of entries written
module Poetry
  module Docs
    class SearchIndex
      PATH = Poetry::Docs.root.join("data/search-index.json")

      class << self
        def build
          session = ActionDispatch::Integration::Session.new(Rails.application)
          session.host!("localhost") # dev host authorization blocks the default example.com
          DocsCatalog.all.flat_map do |entry|
            session.get(entry.path)
            raise "search index: #{entry.path} returned #{session.response.status}" unless session.response.ok?

            page = { "title" => entry.title, "page" => entry.title,
                     "section" => entry.section, "path" => entry.path }
            [ page, *heading_entries_for(entry, Nokogiri::HTML5(session.response.body)) ]
          end
        end

        def write!
          entries = build
          refuse_shared_addresses!(entries)
          PATH.write("#{JSON.pretty_generate(entries)}\n")
          entries.size
        end

        # Two entries with one address: a section whose id is also an
        # example's name on the same page, most often. The command palette
        # takes each address once and raises on the second, on every page
        # it renders on, the pages the next rebuild reads among them. So
        # the index is not written, and the file on disk stays good.
        #
        # @param entries [Array<Hash>]
        # @raise [ArgumentError] naming each shared address
        def refuse_shared_addresses!(entries)
          shared = entries.map { |entry| entry["path"] }.tally.select { |_, count| count > 1 }.keys
          return if shared.empty?

          raise ArgumentError, "the search index would hold #{shared.size} address(es) twice: #{shared.join(", ")}. " \
                               "A section's id and an example's name on one page make the same anchor; rename one."
        end

        # A digest of the committed index, for cache keys: the palette that
        # renders these entries changes only when this file or the gems do.
        def digest
          @digest ||= PATH.exist? ? Digest::SHA256.file(PATH).hexdigest[0, 16] : "none"
        end

        def entries
          @entries ||= PATH.exist? ? JSON.parse(PATH.read) : []
        end

        def headings
          entries.select { |entry| entry["path"].include?("#") }
        end

        private

        # h2/h3 with stable ids only; component-generated ids (poetry-* carry a
        # per-render random suffix) would both pollute the index and flake the
        # freshness gate.
        def heading_entries_for(entry, doc)
          doc.css("main h2[id], main h3[id]")
             .reject { |heading| heading[:id].start_with?("poetry-") }
             .map do |heading|
               { "title" => heading.text.strip, "page" => entry.title,
                 "section" => entry.section, "path" => "#{entry.path}##{heading[:id]}" }
             end
        end
      end
    end
  end
end
