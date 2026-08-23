# frozen_string_literal: true

module Poetry
  module Charts
    module Geometry
      # d3-shape stack() (src/stack.js + offset/{none,expand,diverging}.js,
      # order none): rows x series keys -> per-series [base, top] pairs.
      # Missing values behave as JS +undefined = NaN (the offsets carry the
      # exact NaN fallbacks). :expand normalizes each row to sum 1;
      # :diverging routes negatives below the axis - the beyond-shadcn
      # offsets are ~20 lines here, cheap to carry for the chart families
      # that need them.
      #
      # @example Stack two series over shared rows
      #   Poetry::Charts::Geometry::Stack.new(keys: %w[a b]).series(rows)
      class Stack
        OFFSETS = %i[none expand diverging].freeze

        Series = ::Struct.new(:key, :index, :points) do
          def [](index)
            points[index]
          end

          def length
            points.length
          end
        end

        def initialize(keys:, value: nil, offset: :none)
          @keys = keys.to_a
          @value = value || ->(d, key) { d[key] }
          raise ArgumentError, "unknown stack offset #{offset.inspect}" unless OFFSETS.include?(offset.to_sym)

          @offset = offset.to_sym
        end

        def series(data)
          data = data.to_a
          sz = @keys.map { |key| Series.new(key, nil, []) }

          data.each do |d|
            sz.each do |s|
              value = @value.call(d, s.key)
              s.points << [0.0, value.nil? ? Float::NAN : value.to_f]
            end
          end

          order = (0...sz.length).to_a
          order.each_with_index { |series_index, i| sz[series_index].index = i }

          apply_offset(sz, order)
          sz
        end

        private

        def apply_offset(series, order)
          case @offset
          when :none then offset_none(series, order)
          when :expand then offset_expand(series, order)
          when :diverging then offset_diverging(series, order)
          end
        end

        # Each series bases on the previous series' top (NaN tops fall back
        # to the previous base - the JS isNaN branch).
        def offset_none(series, order)
          return unless series.length > 1

          s1 = series[order[0]]
          m = s1.length
          (1...series.length).each do |i|
            s0 = s1
            s1 = series[order[i]]
            (0...m).each do |j|
              base = s0.points[j][1].nan? ? s0.points[j][0] : s0.points[j][1]
              s1.points[j][0] = base
              s1.points[j][1] += base
            end
          end
        end

        # Normalize each row to [0, 1] (percent stacking), then stack.
        def offset_expand(series, order)
          return if series.empty?

          m = series[0].length
          (0...m).each do |j|
            sum = series.sum { |s| s.points[j][1].nan? ? 0.0 : s.points[j][1] }
            series.each { |s| s.points[j][1] /= sum } unless sum.zero?
          end
          offset_none(series, order)
        end

        # Positives stack up from zero, negatives stack down.
        def offset_diverging(series, order)
          return if series.empty?

          m = series[order[0]].length
          (0...m).each do |j|
            yp = 0.0
            yn = 0.0
            order.each do |series_index|
              point = series[series_index].points[j]
              dy = point[1] - point[0]
              if dy.positive?
                point[0] = yp
                point[1] = (yp += dy)
              elsif dy.negative?
                point[1] = yn
                point[0] = (yn += dy)
              else
                point[0] = 0.0
                point[1] = dy
              end
            end
          end
        end
      end
    end
  end
end
