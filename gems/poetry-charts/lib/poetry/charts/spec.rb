# frozen_string_literal: true

module Poetry
  module Charts
    # The chart-spec: the CLOSED, VERSIONED description every poetry chart
    # compiles to. The server engine consumes it Ruby-side; swappable
    # adapters consume the same spec JSON-side through the duck-typed
    # protocol (render(el, spec) / update / destroy). No engine-specific key
    # ever enters this schema - engine styling lives in the adapter,
    # declared; a pass-through options bag would tie call sites to one
    # engine and the spec could never close.
    #
    # Keys ride the wire camelCased (dataKey, stackId) - one vocabulary
    # on both sides of the seam.
    #
    # @example Compile a spec and serialize it for an adapter
    #   Poetry::Charts::Spec.new(
    #     type: :bar, data: rows, series: [{ data_key: :revenue }]
    #   ).to_json
    class Spec
      # The spec schema version stamped into every payload.
      VERSION = 1

      # The chart types the spec can describe.
      TYPES = %i[area bar line pie radar radial].freeze

      # The closed key set a series entry may carry.
      SERIES_KEYS = %i[key data_key name_key stack curve].freeze
      # The closed key set an axis entry may carry.
      AXIS_KEYS = %i[data_key hide tick_count format].freeze

      attr_reader :type, :data, :series, :axes, :config

      # @param type [Symbol, String] one of TYPES
      # @param data [Array<Hash>] the rows, one hash per data point
      # @param series [Array<Hash>] series entries; data_key: is required
      # @param axes [Hash] per-axis settings (SERIES_KEYS/AXIS_KEYS closed sets)
      # @param config [Config, Hash, nil] label/color config, wrapped via Config.wrap
      def initialize(type:, data:, series:, axes: {}, config: nil)
        @type = type.to_sym
        unless TYPES.include?(@type)
          raise ArgumentError,
                "unknown chart type #{type.inspect} (one of #{TYPES.join(", ")})"
        end

        @data = Array(data)
        @series = normalize_series(series)
        @axes = normalize_axes(axes)
        @config = Config.wrap(config)
      end

      # The wire form: string keys, camelCased entry keys, the version
      # stamped in.
      #
      # @return [Hash]
      def to_h
        {
          "version" => VERSION,
          "type" => type.to_s,
          "data" => data.map { |row| row.to_h.transform_keys(&:to_s) },
          "series" => series.map { |entry| camelize_keys(entry) },
          "axes" => axes.to_h { |name, axis| [name.to_s, camelize_keys(axis)] },
          "config" => config.to_h.transform_values { |value| camelize_keys(value) }
        }
      end

      # The wire form serialized - what the spec <script> embeds.
      #
      # @return [String]
      def to_json(...)
        to_h.to_json(...)
      end

      private

      def normalize_series(series)
        Array(series).map do |entry|
          entry = entry.symbolize_keys
          raise ArgumentError, "a series entry requires data_key: (got #{entry.inspect})" unless entry[:data_key]

          unknown = entry.keys - SERIES_KEYS
          raise ArgumentError, "unknown series keys #{unknown.inspect} (the spec is closed)" if unknown.any?

          { key: entry[:data_key].to_s }.merge(entry).compact
        end
      end

      def normalize_axes(axes)
        axes.symbolize_keys.to_h do |name, axis|
          axis = axis.symbolize_keys
          unknown = axis.keys - AXIS_KEYS
          raise ArgumentError, "unknown axis keys #{unknown.inspect} on #{name} (the spec is closed)" if unknown.any?

          [name, axis]
        end
      end

      # snake_case Ruby -> camelCase wire (dataKey, stackId-style).
      # Symbol values (data keys, curve names) become strings on the
      # wire.
      def camelize_keys(hash)
        hash.to_h do |key, value|
          [key.to_s.camelize(:lower), value.is_a?(Symbol) ? value.to_s : value]
        end
      end
    end
  end
end
