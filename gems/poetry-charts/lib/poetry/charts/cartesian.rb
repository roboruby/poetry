# frozen_string_literal: true

module Poetry
  module Charts
    # The server-side cartesian layout pipeline: data + series ->
    # plot rectangle, scales, ticks, and per-series pixel points - computed
    # top-down in one pass. This is the knowledge recharts reconstructs
    # through its per-chart store; a server renderer starts with it.
    #
    # Layout follows recharts' conventions so the shadcn blocks translate
    # 1:1: default margin 5 on every side, x-axis strip height 30 at the
    # bottom when shown, category x positions from a zero-padding point
    # scale (first/last categories AT the plot edges - the reason blocks
    # add left/right margin 12), numeric y domain [0, auto] niced by the
    # recharts algorithm (implicit tickCount 5), stacking per stack id
    # with d3's offsets.
    class Cartesian
      DEFAULT_MARGIN = { top: 5, right: 5, bottom: 5, left: 5 }.freeze
      X_AXIS_HEIGHT = 30

      OFFSETS = %i[none expand].freeze

      attr_reader :width, :height, :margin, :y_tick_count, :offset

      def initialize(data:, series:, width:, height:, x_key: nil, margin: {},
                     x_axis: true, y_tick_count: 5, offset: :none, x_scale_type: :point)
        @data = data.map { |row| row.to_h.transform_keys(&:to_s) }
        @series = series
        @width = width.to_f
        @height = height.to_f
        @x_key = x_key&.to_s
        @margin = DEFAULT_MARGIN.merge(margin.to_h.symbolize_keys)
        @x_axis = x_axis
        @y_tick_count = y_tick_count
        @x_scale_type = x_scale_type.to_sym
        raise ArgumentError, "unknown offset #{offset.inspect}" unless OFFSETS.include?(offset.to_sym)

        @offset = offset.to_sym
      end

      # -- the plot rectangle ---------------------------------------------------

      def plot_left = margin[:left].to_f
      def plot_right = width - margin[:right]
      def plot_top = margin[:top].to_f

      def plot_bottom
        height - margin[:bottom] - (@x_axis ? X_AXIS_HEIGHT : 0)
      end

      # -- x: categories on a point scale ---------------------------------------

      def categories
        @categories ||= @x_key ? @data.map { |row| row[@x_key] } : (0...@data.length).to_a
      end

      # Point for line/area (categories AT the edges); band for bars
      # (recharts' zero-padding band - the bar gaps come from
      # barCategoryGap/barGap math inside the band, not scale padding).
      def x_scale
        @x_scale ||= if @x_scale_type == :band
                       Geometry::Scale::Band.new(domain: categories, range: [plot_left, plot_right])
                     else
                       Geometry::Scale::Point.new(domain: categories, range: [plot_left, plot_right])
                     end
      end

      def x_positions
        x_scale.positions
      end

      def band_width
        x_scale.bandwidth
      end

      # The per-category CENTER - where ticks, vertical grid lines, and the
      # tooltip's hit columns sit (band centers; point positions verbatim).
      def x_centers
        @x_centers ||= if @x_scale_type == :band
                         half = band_width / 2.0
                         x_positions.map { |x| x + half }
                       else
                         x_positions
                       end
      end

      # -- y: numeric domain, recharts-niced -------------------------------------

      def y_ticks
        @y_ticks ||= if offset == :expand
                       Geometry::NiceTicks.nice_ticks([0, 1], y_tick_count)
                     else
                       Geometry::NiceTicks.nice_ticks(raw_domain, y_tick_count)
                     end
      end

      def y_domain
        [y_ticks.first, y_ticks.last]
      end

      def y_scale
        @y_scale ||= Geometry::Scale::Linear.new(domain: y_domain, range: [plot_bottom, plot_top])
      end

      # The area baseline: the y pixel of 0, clamped into the domain
      # (recharts' Area baseline semantics).
      def baseline
        y_scale.call(0.0.clamp(y_domain.first, y_domain.last))
      end

      # -- per-series points -----------------------------------------------------

      # [{x:, y0:, y1:, value:}] for one series entry - stacked entries ride
      # their stack group's d3 offsets; independent entries base on the
      # baseline. NaN values (missing data) flow through as NaN, which the
      # generators' defined-gap machinery turns into path gaps.
      def points(entry)
        key = entry.key
        if entry.stack
          bands = stacked_bands(entry.stack)[key]
          bands.each_with_index.map do |(lo, hi), i|
            { x: x_centers[i], y0: y_scale.call(lo), y1: y_scale.call(hi), value: value_at(i, key) }
          end
        else
          @data.each_with_index.map do |_row, i|
            value = value_at(i, key)
            { x: x_centers[i], y0: baseline, y1: y_scale.call(value), value: value }
          end
        end
      end

      # -- W5 handoff: the embedded coordinates ----------------------------------

      # Compact per-series pixel coordinates the tooltip controller reads -
      # no chart math in the browser.
      def coordinates
        {
          "categories" => categories,
          "x" => x_centers.map { |x| x.round(2) },
          "series" => @series.to_h do |entry|
            tops = points(entry).map { |p| p[:y1].nan? ? nil : p[:y1].round(2) }
            [entry.key, tops]
          end
        }
      end

      private

      def value_at(index, key)
        value = @data[index][key]
        value.nil? ? Float::NAN : value.to_f
      end

      # d3 stacks per stack id, memoized: { key => [[lo, hi], ...] }.
      def stacked_bands(stack_id)
        @stacked_bands ||= {}
        @stacked_bands[stack_id] ||= begin
          keys = @series.select { |entry| entry.stack == stack_id }.map(&:key)
          stack = Geometry::Stack.new(keys: keys, offset: offset == :expand ? :expand : :none)
          stack.series(@data).to_h { |series| [series.key, series.points] }
        end
      end

      # The raw numeric domain before nicing: [min(0, data), max(data)] -
      # recharts' default [0, 'auto'] domain, stacked series contributing
      # their cumulative tops.
      def raw_domain
        values = []
        @series.each do |entry|
          if entry.stack
            stacked_bands(entry.stack)[entry.key].each do |lo, hi|
              values << lo unless lo.nan?
              values << hi unless hi.nan?
            end
          else
            @data.each_index do |i|
              value = value_at(i, entry.key)
              values << value unless value.nan?
            end
          end
        end
        return [0, 1] if values.empty?

        [[0, values.min].min, values.max]
      end
    end
  end
end
