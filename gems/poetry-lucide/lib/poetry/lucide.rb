# frozen_string_literal: true

require "poetry/core"
require_relative "lucide/version"

# The poetry namespace.
module Poetry
  # The default poetry icon set: Lucide, vendored at a pinned
  # upstream commit (see VENDORED_COMMIT) and sanitized at vendor time by
  # script/fetch_icons.rb - render time never parses or sanitizes.
  module Lucide
    class << self
      # Gem root (the directory containing lib/ and icons/).
      #
      # @return [Pathname]
      def root
        @root ||= Pathname.new(File.expand_path("../..", __dir__))
      end

      # The vendored icons/ tree as the FileSet the icon registry serves.
      #
      # @return [Poetry::Core::Icons::FileSet]
      def set
        @set ||= Poetry::Core::Icons::FileSet.new(dir: root.join("icons"))
      end

      # The upstream lucide-icons/lucide commit the icons/ tree was
      # vendored from (a SHA, never a mutable tag).
      #
      # @return [String] the full commit SHA
      def vendored_commit
        @vendored_commit ||= root.join("icons/VENDORED_COMMIT").read.strip
      end
    end
  end
end

# Requiring the gem IS the setup: registering the set here makes
# `poetry_icon name: :x, set: :lucide` (and set: :lucide anywhere a set is
# accepted) resolve with no further configuration.
Poetry::Core::Icons.register(:lucide, Poetry::Lucide.set)
