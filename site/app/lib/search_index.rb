# The docs search index (N13 W4): every catalog page rendered through an
# integration session, headings extracted from the SAME rendered truth the
# gallery gates walk, committed at public/search-index.json. The palette
# server-renders the heading entries as its Reference group - no client
# fetch, no external indexer, no Node. Regenerate: bin/rails docs:search_index
# (the freshness test fails with that instruction when the file drifts).
class SearchIndex
  PATH = Rails.root.join("public/search-index.json")

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
      PATH.write("#{JSON.pretty_generate(entries)}\n")
      entries.size
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
