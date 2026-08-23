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
    #
    # @example Lay out a plot and read one series' pixel points
    #   plot = Poetry::Charts::Cartesian.new(
    #     data: rows, series: series, width: 600, height: 300
    #   )
    #   plot.points(series.first) # => [{x:, y0:, y1:, value:}, ...]
    class Cartesian
      DEFAULT_MARGIN = { top: 5, right: 5, bottom: 5, left: 5 }.freeze
      X_AXIS_HEIGHT = 30
      # recharts implicit YAxis width - the left strip the horizontal
      # layout's category labels live in.
      Y_AXIS_WIDTH = 60

      OFFSETS = %i[none expand].freeze
      LAYOUTS = %i[vertical horizontal].freeze

      attr_reader :width, :height, :margin, :y_tick_count, :offset, :layout

      # @param data [Array<Hash>] the rows, one hash per category
      # @param series [Array<#key>] series entries (key + optional stack id)
      # @param width [Numeric] outer SVG width in pixels
      # @param height [Numeric] outer SVG height in pixels
      # @param x_key [String, Symbol, nil] the category key; nil indexes rows
      # @param margin [Hash] per-side overrides merged over DEFAULT_MARGIN
      # @param category_axis [Boolean] reserve the category-axis strip
      # @param value_axis [Boolean] a visible value axis reserves the left strip
      # @param y_tick_count [Integer] requested tick count for the niced domain
      # @param offset [Symbol] :none, or :expand for 100%-stacked
      # @param x_scale_type [Symbol] :point (line/area) or :band (bars)
      # @param layout [Symbol] :vertical (values up y) or :horizontal
      def initialize(data:, series:, width:, height:, x_key: nil, margin: {},
                     category_axis: true, value_axis: false, y_tick_count: 5, offset: :none,
                     x_scale_type: :point, layout: :vertical)
        @data = data.map { |row| row.to_h.transform_keys(&:to_s) }
        @series = series
        @width = width.to_f
        @height = height.to_f
        @x_key = x_key&.to_s
        @margin = DEFAULT_MARGIN.merge(margin.to_h.symbolize_keys)
        @category_axis = category_axis
        @value_axis = value_axis
        @y_tick_count = y_tick_count
        @x_scale_type = x_scale_type.to_sym
        @layout = layout.to_sym
        raise ArgumentError, "unknown layout #{layout.inspect}" unless LAYOUTS.include?(@layout)
        raise ArgumentError, "unknown offset #{offset.inspect}" unless OFFSETS.include?(offset.to_sym)

        @offset = offset.to_sym
      end

      def horizontal?
        layout == :horizontal
      end

      # -- the plot rectangle ---------------------------------------------------
      # The category-axis strip sits at the bottom (vertical layout, height
      # 30) or the left (horizontal layout, the implicit YAxis width 60).
      # A VISIBLE value axis in the vertical layout reserves the same left
      # strip (recharts YAxis width 60 - without the reserved strip, shown
      # y labels clipped at the plot edge).

      def plot_left
        reserved = (horizontal? && @category_axis) || (!horizontal? && @value_axis)
        margin[:left].to_f + (reserved ? Y_AXIS_WIDTH : 0)
      end

      def plot_right = width - margin[:right]
      def plot_top = margin[:top].to_f

      def plot_bottom
        height - margin[:bottom] - (!horizontal? && @category_axis ? X_AXIS_HEIGHT : 0)
      end

      # -- x: categories on a point scale ---------------------------------------

      def categories
        @categories ||= @x_key ? @data.map { |row| row[@x_key] } : (0...@data.length).to_a
      end

      # Point for line/area (categories AT the edges); band for bars
      # (recharts' zero-padding band - the bar gaps come from
      # barCategoryGap/barGap math inside the band, not scale padding).
      # Horizontal layout runs the category scale down the Y side.
      def category_range
        horizontal? ? [plot_top, plot_bottom] : [plot_left, plot_right]
      end

      def x_scale
        @x_scale ||= if @x_scale_type == :band
                       Geometry::Scale::Band.new(domain: categories, range: category_range)
                     else
                       Geometry::Scale::Point.new(domain: categories, range: category_range)
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

      # The value scale: y in the vertical layout (inverted - SVG y grows
      # down), x in the horizontal one.
      def y_scale
        @y_scale ||= Geometry::Scale::Linear.new(
          domain: y_domain,
          range: horizontal? ? [plot_left, plot_right] : [plot_bottom, plot_top]
        )
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
      #
      # @param entry [#key] a series entry (key + optional stack id)
      # @return [Array<Hash>] one orientation-aware point hash per category
      def points(entry)
        key = entry.key
        if entry.stack
          bands = stacked_bands(entry.stack)[key]
          bands.each_with_index.map do |(lo, hi), i|
            point_for(i, key, y_scale.call(lo), y_scale.call(hi))
          end
        else
          @data.each_with_index.map do |_row, i|
            point_for(i, key, baseline, y_scale.call(value_at(i, key)))
          end
        end
      end

      # -- the tooltip handoff: the embedded coordinates -------------------------

      # Compact per-series pixel coordinates the tooltip controller reads -
      # no chart math in the browser.
      def coordinates
        top_key = horizontal? ? :x1 : :y1
        band = ({ "x" => x_positions.map { |x| x.round(2) }, "width" => band_width.round(2) } if @x_scale_type == :band)
        {
          "layout" => layout.to_s,
          "categories" => categories,
          # The category-center axis the tooltip bisects along: x in the
          # vertical layout, y in the horizontal one.
          (horizontal? ? "y" : "x") => x_centers.map { |c| c.round(2) },
          "series" => @series.to_h do |entry|
            tops = points(entry).map { |p| p[top_key].nan? ? nil : p[top_key].round(2) }
            [entry.key, tops]
          end,
          # PRE-FORMATTED display strings (from the RAW row values, so
          # integers stay integers) - the controller never formats.
          "values" => @series.to_h do |entry|
            [entry.key, @data.map { |row| display_value(row[entry.key]) }]
          end
        }.merge(band ? { "band" => band } : {})
      end

      private

      # Orientation-aware point: vertical = {x, y0, y1}; horizontal =
      # {y, x0, x1} (values run along x, categories down y).
      def point_for(index, key, base_px, top_px)
        value = value_at(index, key)
        if horizontal?
          { y: x_centers[index], x0: base_px, x1: top_px, value: value }
        else
          { x: x_centers[index], y0: base_px, y1: top_px, value: value }
        end
      end

      def value_at(index, key)
        value = @data[index][key]
        value.nil? ? Float::NAN : value.to_f
      end

      def display_value(value)
        Poetry::Charts.display_value(value)
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
