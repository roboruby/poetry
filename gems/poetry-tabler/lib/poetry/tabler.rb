# frozen_string_literal: true

require "poetry/core"
require_relative "tabler/version"

# The poetry namespace.
module Poetry
  # Tabler Icons as a Poetry icon set, vendored at a pinned upstream commit
  # (see vendored_commit) and sanitized at vendor time by
  # script/fetch_icons.rb - render time never parses or sanitizes. Each
  # variant is one packed file under icons/, registered under its own
  # library key.
  module Tabler
    # Library key => [packed file under icons/, the <svg> wrapper's
    # drawing attributes].
    VARIANTS = {
      tabler: ["outline.tsv", Poetry::Core::Icons::DEFAULT_SVG_ATTRIBUTES],
      tabler_filled: ["filled.tsv",
                      { "width" => "24", "height" => "24", "viewBox" => "0 0 24 24",
                        "fill" => "currentColor" }.freeze]
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
      def set(key = :tabler)
        sets.fetch(key.to_sym)
      end

      # The upstream tabler/tabler-icons commit the icons were vendored from (a
      # SHA, never a mutable tag).
      #
      # @return [String] the full commit SHA
      def vendored_commit
        @vendored_commit ||= root.join("icons/VENDORED_COMMIT").read.strip
      end
    end
  end
end

# Requiring the gem IS the setup: every variant registers under its key,
# so `poetry_icon name: :x, library: :tabler` resolves with no further
# configuration, and `config.icon_library = :tabler` makes it the default.
Poetry::Tabler.sets.each { |key, set| Poetry::Core::Icons.register(key, set) }
