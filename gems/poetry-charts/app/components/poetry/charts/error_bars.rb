# frozen_string_literal: true

module Poetry
  module Charts
    # Error bars: recharts ErrorBar for line, bar, and
    # scatter series. A series slot takes error_key: naming a row key
    # holding either a symmetric offset (err) or [low, high] offsets from
    # the value; the whisker renders cap - stem - cap in the foreground
    # color (recharts' neutral default - visible over same-colored marks),
    # width 5 like recharts.
    module ErrorBars
      DEFAULT_WIDTH = 5

      # [low_value, high_value] in DATA units, or nil when the row has no
      # error entry.
      def error_range(row, error_key, value)
        err = row.to_h.transform_keys(&:to_s)[error_key.to_s]
        return nil if err.nil?

        low, high = err.is_a?(Array) ? err : [err, err]
        [value - low.to_f, value + high.to_f]
      end

      # cap - stem - cap around a vertical span, in pixels.
      def error_bar_path(center_x, y_low, y_high, width)
        half = width.to_f / 2.0
        f = ->(v) { fnum(v) }
        "M#{f.call(center_x - half)},#{f.call(y_low)}H#{f.call(center_x + half)}" \
          "M#{f.call(center_x)},#{f.call(y_low)}V#{f.call(y_high)}" \
          "M#{f.call(center_x - half)},#{f.call(y_high)}H#{f.call(center_x + half)}"
      end
    end
  end
end
