# frozen_string_literal: true

require "poetry/core"
require "yaml"
require_relative "charts/version"
require_relative "charts/config"
require_relative "charts/theme_style"
require_relative "charts/spec"
require_relative "charts/geometry"
require_relative "charts/cartesian"
require_relative "charts/polar"

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

      # The registry builder this gem commits from (the poetry-ui shared-
      # builder rule: rake registry:generate/verify and the sync test share
      # ONE construction). helper_args carries each poetry_* helper's max
      # positional arity from its real signature - poetry_chart(type, ...)
      # legitimately takes one, which is exactly why arity is an emitted
      # per-helper fact and never a convention.
      def registry
        # The helpers section carries the dispatcher's yields declaration:
        # poetry_chart(type) routes to a component that yields its slot
        # builder, so its block param is legitimate - the one exception to
        # the no-wrapper-yields invariant.
        Poetry::Core::Registry.new(
          source_root: root, helper_args: registry_helper_args,
          helpers: { "poetry_chart" => { "yields" => "the dispatched chart component" } }
        )
      end

      # The shadcn-interop item projection (Ecosystem v1), boot-free
      # from the COMMITTED registry - the docs site aggregates this with
      # poetry-ui's for /r/*.json.
      def registry_items
        Poetry::Core::RegistryItems.new(
          registry: YAML.safe_load_file(root.join(Poetry::Core::Registry::RELATIVE_PATH)),
          root: root, gem_name: "poetry-charts", gem_version: VERSION
        )
      end

      POSITIONAL_PARAM_KINDS = %i[req opt].freeze

      def registry_helper_args
        require root.join("app/helpers/poetry/charts/components_helper.rb")
        ComponentsHelper.public_instance_methods(false).grep(/\Apoetry_/).sort.filter_map do |name|
          params = ComponentsHelper.instance_method(name).parameters
          next if params.any? { |kind, _param| kind == :rest }

          [name.to_s, params.count { |kind, _param| POSITIONAL_PARAM_KINDS.include?(kind) }]
        end.to_h
      end

      # The tooltip display string shared by every chart family (matches
      # TooltipContent's Row: delimited numerics from RAW values so
      # integers stay integers, verbatim strings, nil for missing).
      def display_value(value)
        return nil if value.nil?
        return ActiveSupport::NumberHelper.number_to_delimited(value) if value.is_a?(Numeric)

        value.to_s
      end
    end
  end
end

require_relative "charts/engine"
