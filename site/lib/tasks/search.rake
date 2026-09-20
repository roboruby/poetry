namespace :docs do
  desc "Regenerate public/search-index.json from the rendered pages"
  task search_index: :environment do
    count = SearchIndex.write!
    puts "wrote public/search-index.json (#{count} entries)"
  end
end
