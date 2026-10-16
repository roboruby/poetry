# frozen_string_literal: true

require "poetry/core"
require "json"
require_relative "simple_icons/version"

# The poetry namespace.
module Poetry
  # Simple Icons as a Poetry icon set, vendored at a pinned upstream commit
  # (see vendored_commit) and sanitized at vendor time by
  # script/fetch_icons.rb - render time never parses or sanitizes. Each
  # variant is one packed file under icons/, registered under its own
  # library key.
  module SimpleIcons
    # Library key => [packed file under icons/, the <svg> wrapper's
    # drawing attributes].
    VARIANTS = {
      simple_icons: ["brands.tsv",
                     { "width" => "24", "height" => "24", "viewBox" => "0 0 24 24", "fill" => "currentColor" }.freeze]
    }.freeze

    class << self
      # Gem root (the directory containing lib/ and icons/).
      #
      # @return [Pathname]
      def root
        @root ||= Pathname.new(File.expand_path("../..", __dir__))
      end

      # Every variant as the PackedSet the icon registry serves, by
      # library key.
      #
      # @return [Hash{Symbol => Poetry::Core::Icons::PackedSet}]
      def sets
        @sets ||= VARIANTS.to_h do |key, (file, svg_attributes)|
          [key, Poetry::Core::Icons::PackedSet.new(path: root.join("icons", file), svg_attributes: svg_attributes)]
        end.freeze
      end

      # One variant's set.
      #
      # @param key [Symbol] a library key from {VARIANTS}
      # @return [Poetry::Core::Icons::PackedSet]
      def set(key = :simple_icons)
        sets.fetch(key.to_sym)
      end

      # The upstream simple-icons/simple-icons commit the icons were vendored from (a
      # SHA, never a mutable tag).
      #
      # @return [String] the full commit SHA
      def vendored_commit
        @vendored_commit ||= root.join("icons/VENDORED_COMMIT").read.strip
      end

      # A brand's name and colour from Simple Icons' data, for the
      # logo in its own colour: `style: "color: ##{brand[:hex]}"`.
      #
      # @param name [Symbol, String] the icon name
      # @return [Hash{Symbol => String}, nil] `{ title:, hex: }`, or nil
      #   for a name the set does not have
      def brand(name)
        @brands ||= JSON.parse(root.join("icons/brands.json").read).transform_values(&:freeze).freeze
        entry = @brands[name.to_s] or return nil

        { title: entry["title"], hex: entry["hex"] }
      end
    end
  end
end

# Requiring the gem IS the setup: every variant registers under its key,
# so `poetry_icon name: :x, library: :simple_icons` resolves with no further
# configuration, and `config.icon_library = :simple_icons` makes it the default.
Poetry::SimpleIcons.sets.each { |key, set| Poetry::Core::Icons.register(key, set) }
