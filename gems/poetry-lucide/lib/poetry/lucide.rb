# frozen_string_literal: true

require "poetry/core"
require_relative "lucide/version"

module Poetry
  # The default poetry icon set: Lucide, vendored at a pinned
  # upstream commit (see VENDORED_COMMIT) and sanitized at vendor time by
  # script/fetch_icons.rb - render time never parses or sanitizes.
  module Lucide
    class << self
      def root
        @root ||= Pathname.new(File.expand_path("../..", __dir__))
      end

      def set
        @set ||= Poetry::Core::Icons::FileSet.new(dir: root.join("icons"))
      end

      # The upstream lucide-icons/lucide commit the icons/ tree was
      # vendored from (a SHA, never a mutable tag).
      def vendored_commit
        @vendored_commit ||= root.join("icons/VENDORED_COMMIT").read.strip
      end
    end
  end
end

Poetry::Core::Icons.register(:lucide, Poetry::Lucide.set)
