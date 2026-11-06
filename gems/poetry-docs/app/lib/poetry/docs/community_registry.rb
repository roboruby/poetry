# The community registry's index, read for the Community pages: the
# directory Poetry::Docs.config.community_registry names holds what the
# registry's build wrote (registry.json, one <name>.json per item, and
# screenshots/). The index describes each item - the files it writes, its
# demo's source, its screenshot and, for a component, the helper, options,
# style axes, slots and agent rules - so the pages show an item without
# running any of it. No directory configured means no items.
#
# @example The items a host serves
#   CommunityRegistry.items.map(&:name)
module Poetry
  module Docs
    class CommunityRegistry
      NAME = /\A[a-z0-9]+(-[a-z0-9]+)*\z/
      SCREENSHOT = %r{\Ascreenshots/[a-z0-9]+(-[a-z0-9]+)*\.webp\z}
      KINDS = { "registry:block" => "Block", "registry:style" => "Restyle", "registry:lib" => "Library" }.freeze

      # One item, from its detail file. Every reader answers for a file
      # that says less (an older build): a missing fact is nil or empty,
      # never a raise.
      class Item
        attr_reader :entry

        def initialize(entry)
          @entry = entry
        end

        def name = entry["name"]

        def title = entry["title"].presence || name.tr("-", " ").capitalize

        def description = entry["description"].to_s

        def kind = KINDS.fetch(entry["type"], "Component")

        # What poetry:add takes: the gems ship no item of this name, so the
        # @poetry address fetches it from the community registry.
        def address = "@poetry/#{name}"

        def install = "bin/rails g poetry:add #{address}"

        def version = meta["version"].presence

        # The ERB the registry's pilot host renders for the screenshot.
        def demo = meta["demo"].presence

        # What the item's author says to do after the install.
        def notes = entry["docs"].presence

        def files = hashes(entry["files"]).filter_map { |file| file["target"] || file["path"] }

        def gems = Array(entry["dependencies"]).map(&:to_s)

        def needs = Array(entry["registryDependencies"]).map(&:to_s)

        # Every origin a port credits: meta.sources (a bundle with its
        # libraries inside), or the one meta.source. An original item has none.
        def origins
          sources = hashes(meta["sources"])
          sources.any? ? sources : hashes([ meta["source"] ])
        end

        # The screenshot's path under the registry (screenshots/<name>.webp)
        # and its pixels, or nil. It was taken at twice the demo's size.
        def screenshot
          shot = meta["screenshot"]
          shot if shot.is_a?(Hash) && shot["path"].to_s.match?(SCREENSHOT)
        end

        # How an item's JavaScript level reads on its page.
        JAVASCRIPT = { "none" => "no JavaScript of its own", "stimulus" => "a Stimulus controller",
                       "island" => "a client island" }.freeze

        # The JavaScript an item brings, in words; nil where the index
        # does not say.
        def javascript = JAVASCRIPT[meta["javascript"]]

        # The JavaScript an item brings, as the registry states it
        # ("none", "stimulus", "island"); nil where it does not say.
        def javascript_level = meta["javascript"].presence

        # The library a port came from, by its key ("acme" for @acme);
        # nil for an item made for Poetry.
        def library = origins.first&.dig("registry").to_s.delete_prefix("@").presence

        # What the item looks like whatever theme the app wears.
        def traits = Array(meta["traits"]).map(&:to_s)

        # The Poetry component a restyle changes the look of.
        def restyles = meta["restyles"].presence

        def helper = component["helper"].presence

        # Required first, then by name.
        def options = hashes(component["options"]).sort_by { |option| [ option["required"] ? 0 : 1, option["name"].to_s ] }

        def styles = hashes(component["styles"])

        def slots = hashes(component["slots"])

        def agent_rules = Array(component["agent_rules"]).map(&:to_s)

        private

        def meta = entry["meta"].is_a?(Hash) ? entry["meta"] : {}

        def component = meta["component"].is_a?(Hash) ? meta["component"] : {}

        def hashes(value) = Array(value).grep(Hash)
      end

      class << self
        # The directory the host configured, or nil.
        def root
          configured = Poetry::Docs.config.community_registry
          Pathname(configured).expand_path if configured.present?
        end

        # A file inside the directory, or nil. The expanded path is checked
        # to stay inside it, whatever the route let through.
        def file(relative)
          dir = root
          return nil unless dir

          path = dir.join(relative).expand_path
          path if path.to_s.start_with?("#{dir}/") && path.file?
        end

        # The items, by name: one for each detail file the registry keeps
        # (about/<name>.json), which holds what a list and the item's own
        # page show of it. The registry has no index of them. A file that
        # does not parse, or that is not about the item it is named for,
        # is left out. The files are read once for a directory as it
        # stands, and again when one of them changes.
        def items
          dir = root&.join("about")
          return [] unless dir&.directory?

          paths = dir.glob("*.json").sort
          stamp = paths.map { |path| [ path.to_s, path.mtime, path.size ] }
          return @items if @stamp == stamp

          @stamp = stamp
          @items = paths.filter_map { |path| item_at(path) }
        end

        def find(name)
          items.find { |item| item.name == name }
        end

        # The item a detail file is about, or nil.
        def item_at(path)
          entry = JSON.parse(path.read)
          Item.new(entry) if entry.is_a?(Hash) && entry["name"].to_s.match?(NAME) && entry["name"] == path.basename(".json").to_s
        rescue JSON::ParserError
          nil
        end

        # Where an item's saved demo runs, or nil: the configured demos
        # address, when it is a web address at another origin than
        # +apart_from+ (the docs site's own). The frame an item's page
        # loads it into lets the demo's scripts run, which is safe only
        # while the two origins differ.
        def demo_url(name, apart_from:)
          demos = origin(Poetry::Docs.config.community_demos)
          "#{demos}/items/#{name}/" if demos && demos != origin(apart_from)
        end

        private

        # scheme://host[:port] of a web address, or nil.
        def origin(address)
          uri = URI.parse(address.to_s.strip)
          return nil unless uri.is_a?(URI::HTTP) && uri.host.present?

          "#{uri.scheme}://#{uri.host.downcase}#{":#{uri.port}" unless uri.port == uri.default_port}"
        rescue URI::InvalidURIError
          nil
        end
      end
    end
  end
end
