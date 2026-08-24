# frozen_string_literal: true

module Poetry
  module Charts
    # The bring-your-own-engine chart mount.
    module AdapterChart
      # The BYO-engine mount: `poetry_chart :bar, engine:
      # "chartjs", ...` renders the Container frame (theming intact), a
      # mount element, and the FROZEN chart-spec v1 - the registered
      # adapter draws whatever it likes inside. The seam is deliberately
      # whole-chart coarse: the compositional slot grammar belongs to the
      # default engine; adapters consume the closed spec via series:/axes:
      # arguments.
      #
      # @example
      #   <%= poetry_chart :bar, engine: "chartjs", data: data, config: config,
      #                    series: [{ data_key: :desktop }], axes: { x: { data_key: :month } } %>
      class Component < Poetry::Core::Component
        # Projected into the registry and agent surface.
        AGENT_RULES = [
          "The adapter path takes series:/axes: ARGUMENTS (the closed spec), not slots.",
          "The host must register the engine first: registerChartAdapter(name, adapter) - " \
          "poetry ships createChartJsAdapter(Chart) as the reference.",
          "The Container contract still applies: config colors, --chart tokens, dark mode.",
          "Prefer the default engine; adapters are for engine-specific needs (e.g. >10k points on canvas)."
        ].freeze

        # The adapter seam's whole JS surface: the frame registers the
        # controller with the engine name, the mount div and the spec
        # <script> are its two targets.
        use_stimulus do
          on :frame do
            controller "poetry--charts--adapter" do
              register
              value :engine
            end
          end
          on :mount do
            controller("poetry--charts--adapter") { target :mount }
          end
          on :spec do
            controller("poetry--charts--adapter") { target :spec }
          end
        end

        # The chart type carried in the spec (see Spec::TYPES).
        option :type, :symbol, required: true
        # The registered adapter's name; the controller hands it the
        # mount and the spec.
        option :engine, :string, required: true
        # The rows to plot, serialized into the spec.
        option :data, ActiveModel::Type::Value.new, required: true
        # The series config - key => { label:, color: } - naming and
        # coloring every series.
        option :config, ActiveModel::Type::Value.new, required: true
        # The series list ({ data_key:, ... } hashes) - the closed spec's
        # replacement for slots.
        option :series, ActiveModel::Type::Value.new, required: true
        # The axis config ({ x:, y: } hashes), also spec-carried.
        option :axes, ActiveModel::Type::Value.new
        # Explicit DOM id token, stable across renders; otherwise the
        # chart gets a unique per-render id.
        option :id, :string
        # Accessible name for the mount; defaults to one built from the
        # type and engine.
        option :label, :string

        validates :type, inclusion: { in: Spec::TYPES }

        # No part contract yet: adapter_chart has no preview, so the
        # part-contract tier cannot DOM-verify a declaration (the
        # tooltip_layer rule - declare only what verifies). Add previews
        # first, then declare chart-adapter-mount + chart-spec.

        # Built (and validated) server-side - a bad series/axis key raises
        # at render, never in the browser.
        # @api private
        def spec
          @spec ||= Spec.new(type: type, data: data, series: series, axes: axes || {}, config: config)
        end

        # The config: option wrapped as a {Poetry::Charts::Config}.
        # @api private
        def chart_config
          @chart_config ||= Poetry::Charts::Config.wrap(config)
        end

        # The data-chart scope: explicit id when given, else unique per
        # render.
        # @api private
        def chart_id
          @chart_id ||= (dom_id_token(id) ? "chart-#{dom_id_token(id)}" : poetry_instance_id("chart"))
        end

        # The mount's accessible name: explicit label: or a type+engine
        # default.
        # @api private
        def mount_label
          label.presence || "#{type.to_s.capitalize} chart (#{engine})"
        end
      end
    end
  end
end
