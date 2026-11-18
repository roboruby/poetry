# frozen_string_literal: true

require "poetry/core"
require_relative "solar/version"

# The poetry namespace.
module Poetry
  # Solar Icon Set as a Poetry icon set, vendored at a pinned upstream commit
  # (see vendored_commit) and sanitized at vendor time by
  # script/fetch_icons.rb - render time never parses or sanitizes. Each
  # variant is one packed file under icons/, registered under its own
  # library key.
  module Solar
    # The <svg> wrapper every style draws with: each path carries its own
    # stroke or fill.
    DRAWING = { "width" => "24", "height" => "24", "viewBox" => "0 0 24 24", "fill" => "none" }.freeze

    # Library key => [packed file under icons/, the <svg> wrapper's
    # drawing attributes].
    VARIANTS = {
      solar: ["linear.tsv", DRAWING],
      solar_bold: ["bold.tsv", DRAWING],
      solar_bold_duotone: ["bold-duotone.tsv", DRAWING],
      solar_broken: ["broken.tsv", DRAWING],
      solar_line_duotone: ["line-duotone.tsv", DRAWING],
      solar_outline: ["outline.tsv", DRAWING]
    }.freeze

    # The credit CC BY 4.0 requires on every copy: the Icon component
    # renders it as a comment inside each svg, so a host serving the icons
    # carries it without doing anything. Never remove it (only 480 Design
    # may ask for that).
    ATTRIBUTION = "Solar Icon Set by 480 Design, https://www.figma.com/community/file/1166831539721848736, " \
                  "licensed CC BY 4.0, https://creativecommons.org/licenses/by/4.0/, modified for Poetry: " \
                  "inner markup only, colours set to currentColor"

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
          [key,
           Poetry::Core::Icons::PackedSet.new(path: root.join("icons", file), svg_attributes: svg_attributes,
                                              attribution: ATTRIBUTION)]
        end.freeze
      end

      # One variant's set.
      #
      # @param key [Symbol] a library key from {VARIANTS}
      # @return [Poetry::Core::Icons::PackedSet]
      def set(key = :solar)
        sets.fetch(key.to_sym)
      end

      # The upstream saoudi-h/solar-icons commit the icons were vendored from (a
      # SHA, never a mutable tag).
      #
      # @return [String] the full commit SHA
      def vendored_commit
        @vendored_commit ||= root.join("icons/VENDORED_COMMIT").read.strip
      end

      # The credit for a page that shows these icons, CC BY 4.0's
      # recommended visible form: creator, source, license, changes.
      #
      # @return [String]
      def credit
        "Icons: Solar Icon Set by 480 Design (https://www.figma.com/community/file/1166831539721848736), " \
          "CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/), adapted for Poetry"
      end
    end
  end
end

# Requiring the gem IS the setup: every variant registers under its key,
# so `poetry_icon name: :x, library: :solar` resolves with no further
# configuration, and `config.icon_library = :solar` makes it the default.
Poetry::Solar.sets.each { |key, set| Poetry::Core::Icons.register(key, set) }
