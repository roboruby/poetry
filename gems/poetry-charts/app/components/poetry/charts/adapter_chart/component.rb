# frozen_string_literal: true

module Poetry
  module Charts
    module AdapterChart
      # The BYO-engine mount (Door 2): `poetry_chart:bar, engine:
      # "chartjs", ...` renders the Container frame (theming intact), a
      # mount element, and the FROZEN chart-spec v1 - the registered
      # adapter draws whatever it likes inside. The seam is deliberately
      # whole-chart coarse (the proven whole-chart grain): the compositional
      # slot grammar belongs to the default engine; adapters consume the
      # closed spec via series:/axes: arguments.
      class Component < Poetry::Core::Component
        AGENT_RULES = [
          "The adapter path takes series:/axes: ARGUMENTS (the closed spec), not slots.",
          "The host must register the engine first: registerChartAdapter(name, adapter) - " \
          "poetry ships createChartJsAdapter(Chart) as the reference.",
          "The Container contract still applies: config colors, --chart tokens, dark mode.",
          "Prefer the default engine; adapters are for engine-specific needs (e.g. >10k points on canvas)."
        ].freeze

        option :type, :symbol, required: true
        option :engine, :string, required: true
        option :data, ActiveModel::Type::Value.new, required: true
        option :config, ActiveModel::Type::Value.new, required: true
        option :series, ActiveModel::Type::Value.new, required: true
        option :axes, ActiveModel::Type::Value.new
        option :id, :string
        option :label, :string

        validates :type, inclusion: { in: Spec::TYPES }

        # No part contract yet: adapter_chart has no preview, so the
        # tier cannot DOM-verify a declaration (the tooltip_layer rule -
        # declare only what verifies). Add previews first, then declare
        # chart-adapter-mount + chart-spec.

        # Built (and validated) server-side - a bad series/axis key raises
        # at render, never in the browser.
        def spec
          @spec ||= Spec.new(type: type, data: data, series: series, axes: axes || {}, config: config)
        end

        def chart_config
          @chart_config ||= Poetry::Charts::Config.wrap(config)
        end

        def chart_id
          @chart_id ||= "chart-#{dom_id_token(id) || SecureRandom.hex(4)}"
        end

        def mount_label
          label.presence || "#{type.to_s.capitalize} chart (#{engine})"
        end
      end
    end
  end
end
