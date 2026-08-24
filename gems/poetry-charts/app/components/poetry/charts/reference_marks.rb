# frozen_string_literal: true

module Poetry
  module Charts
    # Reference marks - annotation lines, areas, and dots - for every
    # cartesian family. Values speak the chart's own axes - categories on
    # the category axis (the band/point center), numbers on the value
    # axis (scatter overrides both to numeric) - and render as a single
    # group painted ABOVE the series so annotations stay readable over
    # the marks. Labels are strings (the live rule: no lambdas).
    #
    # Hosts provide ref_x_pixel/ref_y_pixel (the concern's defaults speak
    # cartesian), plot edges via cartesian, css(:reference_line/:reference_area/:tick),
    # and fnum. Vertical layouts only (a horizontal bar raises - a
    # declared limit).
    module ReferenceMarks
      def self.included(base)
        # A dashed rule across the plot: x: (a category) draws it
        # vertical, y: (a value) horizontal; label: annotates it.
        base.renders_many :reference_lines, lambda { |x: nil, y: nil, label: nil, stroke_dasharray: "3 3"|
          (@reference_marks ||= []) << { kind: :line, x: x, y: y, label: label,
                                         dasharray: stroke_dasharray.to_s }
          nil
        }

        # A shaded band: any subset of x1/x2/y1/y2 - missing edges extend
        # to the plot's edge.
        base.renders_many :reference_areas, lambda { |x1: nil, x2: nil, y1: nil, y2: nil,
                                                      label: nil, fill_opacity: 0.15|
          (@reference_marks ||= []) << { kind: :area, x1: x1, x2: x2, y1: y1, y2: y2,
                                         label: label, fill_opacity: fill_opacity.to_f }
          nil
        }

        # A marker circle at (x category, y value); r: sets its radius.
        base.renders_many :reference_dots, lambda { |x:, y:, r: 8, label: nil|
          (@reference_marks ||= []) << { kind: :dot, x: x, y: y, r: r.to_f, label: label }
          nil
        }
      end

      # Every declared mark in declaration order, forcing lazy slot
      # evaluation.
      # @api private
      def reference_marks
        reference_lines?
        reference_areas?
        reference_dots?
        @reference_marks ||= []
      end

      # Category-axis values resolve through the category list (teaching
      # error on an unknown category); scatter overrides to numeric.
      # @api private
      def ref_x_pixel(value)
        index = cartesian.categories.index(value)
        unless index
          raise ArgumentError, "reference x #{value.inspect} is not a category " \
                               "(one of #{cartesian.categories.join(", ")})"
        end
        cartesian.x_centers[index]
      end

      # Value-axis values map through the y scale.
      # @api private
      def ref_y_pixel(value)
        cartesian.y_scale.call(value.to_f)
      end

      # The plot rect's edges, keyed for the mark painters.
      # @api private
      def ref_plot
        { left: cartesian.plot_left, right: cartesian.plot_right,
          top: cartesian.plot_top, bottom: cartesian.plot_bottom }
      end

      # The single annotation group, painted above the series.
      # @api private
      def reference_marks_svg
        marks = reference_marks
        return if marks.empty?
        raise ArgumentError, "reference marks support vertical layouts only" if
          respond_to?(:horizontal?) && horizontal?

        tag.g("data-slot": "chart-reference", "aria-hidden": true) do
          safe_join(marks.map { |mark| reference_mark_svg(mark) })
        end
      end

      private

      def reference_mark_svg(mark)
        case mark[:kind]
        when :line then reference_line_svg(mark)
        when :area then reference_area_svg(mark)
        when :dot then reference_dot_svg(mark)
        end
      end

      # x: -> a vertical rule at the category; y: -> a horizontal rule at
      # the value.
      def reference_line_svg(mark)
        plot = ref_plot
        points = if mark[:y]
                   py = ref_y_pixel(mark[:y])
                   { x1: plot[:left], x2: plot[:right], y1: py, y2: py }
                 elsif mark[:x]
                   px = ref_x_pixel(mark[:x])
                   { x1: px, x2: px, y1: plot[:top], y2: plot[:bottom] }
                 else
                   raise ArgumentError, "a reference line needs x: or y:"
                 end

        line = tag.line(class: css(:reference_line), "stroke-dasharray": mark[:dasharray],
                        **points.transform_values { |v| fnum(v) })
        return line unless mark[:label]

        label = tag.text(mark[:label], class: css(:tick), x: fnum(points[:x2] - 4),
                                       y: fnum(points[:y1] - 6), "text-anchor": mark[:y] ? "end" : "start")
        safe_join([line, label])
      end

      # Any subset of x1/x2/y1/y2; missing edges default to the plot
      # rect.
      def reference_area_svg(mark)
        plot = ref_plot
        x1 = mark[:x1] ? ref_x_pixel(mark[:x1]) : plot[:left]
        x2 = mark[:x2] ? ref_x_pixel(mark[:x2]) : plot[:right]
        y1 = mark[:y1] ? ref_y_pixel(mark[:y1]) : plot[:bottom]
        y2 = mark[:y2] ? ref_y_pixel(mark[:y2]) : plot[:top]

        rect = tag.rect(class: css(:reference_area), x: fnum([x1, x2].min), y: fnum([y1, y2].min),
                        width: fnum((x2 - x1).abs), height: fnum((y2 - y1).abs),
                        "fill-opacity": mark[:fill_opacity])
        return rect unless mark[:label]

        label = tag.text(mark[:label], class: css(:tick), x: fnum(([x1, x2].min + [x1, x2].max) / 2.0),
                                       y: fnum([y1, y2].min + 14), "text-anchor": "middle")
        safe_join([rect, label])
      end

      def reference_dot_svg(mark)
        cx = ref_x_pixel(mark[:x])
        cy = ref_y_pixel(mark[:y])
        dot = tag.circle(class: css(:reference_dot), cx: fnum(cx), cy: fnum(cy), r: fnum(mark[:r]))
        return dot unless mark[:label]

        label = tag.text(mark[:label], class: css(:tick), x: fnum(cx),
                                       y: fnum(cy - mark[:r] - 6), "text-anchor": "middle")
        safe_join([dot, label])
      end

      private :ref_x_pixel, :ref_y_pixel, :ref_plot, :reference_marks_svg
    end
  end
end
