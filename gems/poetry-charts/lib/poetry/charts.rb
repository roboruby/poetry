# frozen_string_literal: true

require "poetry/core"
require_relative "charts/version"
require_relative "charts/config"
require_relative "charts/theme_style"
require_relative "charts/spec"
require_relative "charts/geometry"

module Poetry
  # poetry's chart tier: the shadcn chart surface as server-rendered
  # SVG. Ruby runs the whole geometry pipeline - data -> domains -> scales ->
  # ticks -> points -> paths (d3-scale/d3-shape semantics, recharts'
  # decimal-exact nice ticks) - and the finished chart ships in the initial
  # HTML: no-JS/print/email valid, themed by CSS variables (--chart-1..5 +
  # per-chart --color-<key>), dark mode with zero re-render. Stimulus chrome
  # adds tooltip/legend/active interactivity by reading SERVER-EMBEDDED
  # coordinates - no chart math in the browser.
  #
  # Engines stay swappable (the three doors): the container contract is
  # engine-agnostic; every chart also compiles to a closed, VERSIONED
  # chart-spec consumed by duck-typed adapters (render/update/destroy -
  # Chart.js ships as the reference adapter); React chart libraries remain
  # reachable through the island.
  module Charts
    class << self
      # Gem root (the directory containing lib/, app/, config/).
      def root
        @root ||= Pathname.new(File.expand_path("../..", __dir__))
      end
    end
  end
end

require_relative "charts/engine"
