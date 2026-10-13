# frozen_string_literal: true

require "pathname"
require "poetry/core"
require_relative "motion/version"

# The motion behaviors resolve by name beside poetry-core's.
Poetry::Core::Behavior.namespaces << "Poetry::Motion::Behaviors"

module Poetry
  # poetry-motion: opt-in animated effects. The server renders each
  # effect's finished state; the vendored animation engine
  # (`@poetry/motion/engine`) is pinned without preload and fetched by a
  # dynamic import the first time an element asks for it, so a page with no
  # motion element loads none of it. One policy module
  # (`@poetry/motion/policy`) owns reduced motion, the motion tokens, the
  # Turbo cache flush and the one view-transition slot.
  module Motion
    # The gem root.
    #
    # @return [Pathname]
    def self.root
      @root ||= Pathname.new(File.expand_path("../..", __dir__))
    end
  end
end

require_relative "motion/engine" if defined?(Rails::Engine)
