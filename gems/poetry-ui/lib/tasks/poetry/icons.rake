# frozen_string_literal: true

# "Which icon means delete?" answered from the app's own icon set:
# `bin/rails "poetry:icons[delete]"`. The set's names, the names its
# icons used to have and the words its makers file them under are all
# searched, best answer first. The MCP server's find_icon tool gives an
# agent the same answer without booting the app.
# Loaded automatically by the engine (lib/tasks).
namespace :poetry do
  desc "Find an icon by what it should mean, in the app's icon set: bin/rails \"poetry:icons[delete]\""
  task :icons, [:query] => :environment do |_task, args|
    query = [args[:query], *args.extras].compact.join(" ").strip
    abort %(poetry:icons: say what the icon should mean - bin/rails "poetry:icons[delete]") if query.empty?

    matches = Poetry::Core::Icons.find(query, limit: 12)
    if matches.empty?
      abort "poetry:icons: no icon in #{Poetry::Core::Config.current.icon_library.inspect} answers " \
            "#{query.inspect} - say what it draws or what it is used for in one or two plain words"
    end

    width = matches.map { |match| match[:name].length }.max
    matches.each { |match| puts "#{match[:name].ljust(width)}  #{match[:tags].first(6).join(", ")}".rstrip }
  end
end
