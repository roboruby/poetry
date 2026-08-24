# frozen_string_literal: true

module Poetry
  module Charts
    # The identity chassis every chart family shares: the data-chart id
    # scope, the wrapped config, the accessible SVG name, and the SVG
    # number formatter. Families supply svg_label_prefix (the accessible
    # name's chart-type lead-in); a family whose default name reads from a
    # different surface (scatter: series keys through the config) overrides
    # svg_label itself.
    module ChartFamily
      # The data-chart scope: explicit id when given (stable for tests /
      # multiple charts), else unique per render.
      def chart_id
        @chart_id ||= (dom_id_token(id) ? "chart-#{dom_id_token(id)}" : poetry_instance_id("chart"))
      end

      def chart_config
        @chart_config ||= Poetry::Charts::Config.wrap(config)
      end

      # The accessible name for the role=img SVG: explicit label: or a
      # sensible default from the configured series.
      def svg_label
        label.presence || "#{svg_label_prefix}: #{chart_config.entries.map { |e| e.label || e.key }.join(", ")}"
      end

      # SVG attribute numbers: 2-decimal rounding, JS-style formatting
      # (bare integers) - keeps the markup compact and stable.
      def fnum(value)
        Geometry.js_number((value * 100).round / 100.0)
      end
    end
  end
end
