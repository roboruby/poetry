# frozen_string_literal: true

require "poetry/core"
require_relative "heroicons/version"

# The poetry namespace.
module Poetry
  # Heroicons as a Poetry icon set, vendored at a pinned upstream commit
  # (see vendored_commit) and sanitized at vendor time by
  # script/fetch_icons.rb - render time never parses or sanitizes. Each
  # variant is one packed file under icons/, registered under its own
  # library key.
  module Heroicons
    # Library key => [packed file under icons/, the <svg> wrapper's
    # drawing attributes].
    VARIANTS = {
      heroicons: ["outline.tsv",
                  { "width" => "24", "height" => "24", "viewBox" => "0 0 24 24", "fill" => "none",
                    "stroke" => "currentColor", "stroke-width" => "1.5" }.freeze],
      heroicons_solid: ["solid.tsv",
                        { "width" => "24", "height" => "24", "viewBox" => "0 0 24 24",
                          "fill" => "currentColor" }.freeze],
      heroicons_mini: ["mini.tsv",
                       { "width" => "20", "height" => "20", "viewBox" => "0 0 20 20",
                         "fill" => "currentColor" }.freeze],
      heroicons_micro: ["micro.tsv",
                        { "width" => "16", "height" => "16", "viewBox" => "0 0 16 16",
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
      def set(key = :heroicons)
        sets.fetch(key.to_sym)
      end

      # The upstream tailwindlabs/heroicons commit the icons were vendored from (a
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
# so `poetry_icon name: :x, library: :heroicons` resolves with no further
# configuration, and `config.icon_library = :heroicons` makes it the default.
Poetry::Heroicons.sets.each { |key, set| Poetry::Core::Icons.register(key, set) }
