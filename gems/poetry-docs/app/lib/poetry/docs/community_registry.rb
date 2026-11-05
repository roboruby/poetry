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

      # One item of the index. Every reader answers for an index that says
      # less (an older build): a missing fact is nil or empty, never a raise.
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

        # The index's items, in its order. An index that does not parse
        # serves none.
        def items
          path = file("registry.json")
          return [] unless path

          index = JSON.parse(path.read)
          entries = index.is_a?(Hash) ? Array(index["items"]) : []
          entries.select { |entry| entry.is_a?(Hash) && entry["name"].to_s.match?(NAME) }.map { |entry| Item.new(entry) }
        rescue JSON::ParserError
          []
        end

        def find(name)
          items.find { |item| item.name == name }
        end
      end
    end
  end
end
