# frozen_string_literal: true

module Poetry
  module Charts
    # The pie chart family.
    module PieChart
      # Renders a pie or donut chart as server-computed polar sectors.
      # Slices color from their row's fill key, the donut hole comes from
      # inner_radius, stacked pies nest two rings with their own data,
      # and the center label is plain SVG text. The 250x250 viewBox pairs
      # with a square, max-height-capped container, so absolute-pixel
      # radii (inner_radius: 60, active pop-outs of +10) keep the same
      # proportion everywhere. Slices meet flush by default;
      # stroke_width: N opts into var(--background) separators, which
      # hold up in dark mode where a hard-coded white would not.
      #
      # @example A donut with a tooltip
      #   <%= poetry_chart :pie, data: browsers, config: config do |c| %>
      #     <% c.with_pie data_key: :visitors, name_key: :browser, inner_radius: 60 %>
      #     <% c.with_tooltip %>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Charts::ChartFamily
        include Poetry::Charts::TooltipWiring
        include Poetry::Charts::Motion

        # Projected into the registry and agent surface.
        AGENT_RULES = [
          "Rows carry their slice color in a fill key (var(--color-<name>)); the config maps names to labels.",
          "inner_radius: 60 makes the donut; with_center_label(title:, subtitle:) fills the hole.",
          "Stacked pies: two with_pie slots with their own data: and non-overlapping radii.",
          "active_index: pops one slice out by 10px (the donut-active look).",
          "The tooltip walks slices by hover AND arrow keys (role=application when attached).",
          "Entrance animation is on by default (source parity); animate: false for a static chart. " \
          "Reduced-motion users always get the finished chart."
        ].freeze

        # One with_pie call's captured series config.
        Series = Data.define(:data, :data_key, :name_key, :inner_radius, :outer_radius,
                             :padding_angle, :stroke_width, :color_key, :labels, :label_key,
                             :active_index, :active_grow)

        option :data, ActiveModel::Type::Value.new,
               doc: "Default rows for pies that don't bring their own data: - one hash per slice."
        option :config, ActiveModel::Type::Value.new, required: true,
                                                      doc: "The series config - name => { label:, color: } - naming " \
                                                           "and coloring the slices."
        option :id, :string,
               doc: "Explicit DOM id token, stable across renders; otherwise the chart gets a unique per-render id."
        option :width, :integer, default: 250,
                                 doc: "ViewBox width in pixels; the rendered chart scales to its container."
        option :height, :integer, default: 250, doc: "ViewBox height in pixels."
        option :margin, ActiveModel::Type::Value.new,
               doc: "Margin overrides ({ top:, right:, bottom:, left: }), merged over the slim polar default."
        option :label, :string,
               doc: "Accessible name for the chart SVG; defaults to one built from the configured series."

        motion_options(delay: 400)

        part "chart-svg", "The chart canvas (<svg>) - the aria-label surface, the tooltip's " \
                          "focus/keyboard surface (role=application when it attaches), and " \
                          "the motion rig's mount",
             states: {
               "data-animate" => "when animate (the default) - the entrance tier's flag the " \
                                 "motion stylesheet and controller key off",
               "data-motion" => { condition: "runtime, when animate - the motion engine's lifecycle stamp",
                                  values: %w[entrance morph settled] }
             },
             vars: {
               "--poetry-motion-delay" => "the motion rig's entrance delay (animation_begin)",
               "--poetry-motion-duration" => "the motion rig's entrance duration (animation_duration)",
               "--poetry-motion-easing" => "the motion rig's easing keyword (animation_easing)"
             }
        part "chart-pie", "One pie's slice group (<g>) - a ring per with_pie slot",
             states: { "data-key" => "always - the series key" }
        part "chart-pie-sector", "One slice (<path>) - fill from its row's color, popped out when active",
             states: {
               "data-key" => "always - the series key",
               "data-index" => "on the first pie's slices - the datum index the tooltip walks",
               "data-active" => "the active slice - server-rendered via active_index:, and reflected " \
                                "onto the hovered/arrow-keyed index by the tooltip controller at runtime",
               "data-motion-group" => "when animate - the motion rig's sweep group (one per ring)",
               "data-motion-sector" => "when animate - the motion rig's server-computed sector params " \
                                       "for the fan-out sweep"
             }
        part "chart-labels", "A series' value labels (<g> of <text>, aria-hidden), rendered when " \
                             "the series opts into labels",
             states: { "data-key" => "always - the series key" }
        part "chart-center-label", "The center text (<text>) - title tspan plus optional subtitle " \
                                   "filling the chart's middle"
        part "chart-coordinates", "The embedded JSON payload (<script>) the tooltip controller " \
                                  "reads - per-category anchors and pre-formatted values, zero " \
                                  "chart math in the browser"

        renders_many :pies,
                     doc: "One ring of slices reading data_key: values and name_key: slice names. inner_radius: " \
                          "makes the donut; padding_angle: spaces the slices; active_index: pops one out by " \
                          "active_grow: pixels.",
                     renders: lambda { |data_key:, data: nil, name_key: :name, inner_radius: 0,
                                      outer_radius: "80%", padding_angle: 0, stroke_width: 0,
                                      color_key: :fill, labels: nil, label_key: nil,
                                      active_index: nil, active_grow: 10|
                       (@series_entries ||= []) << Series.new(data: data, data_key: data_key.to_s,
                                                              name_key: name_key.to_s, inner_radius:,
                                                              outer_radius:, padding_angle:, stroke_width:,
                                                              color_key: color_key&.to_s, labels: labels&.to_sym,
                                                              label_key: label_key&.to_s, active_index:, active_grow:)
                       nil
                     }
        # ActiveSupport singularizes "pies" to "py" - give the grammar its
        # real name.
        alias with_pie with_py

        renders_one :center_label,
                    doc: "The donut-hole text: a title line plus an optional subtitle.",
                    renders: lambda { |title:, subtitle: nil|
                      @center_label_config = { title: title, subtitle: subtitle }
                      nil
                    }

        renders_one :legend,
                    doc: "The legend row: align:, items:, and hide_icon:.",
                    renders: lambda { |**options|
                      @legend_config = options
                      nil
                    }

        renders_one :tooltip,
                    doc: "The hover tooltip; the slice name carries the label, so hide_label defaults on.",
                    renders: lambda { |**options|
                      @tooltip_config = { hide_label: true }.merge(options)
                      nil
                    }

        # The polar chassis: margin/plot/center geometry plus the
        # per-slice pointerover hit; the single-series tooltip chrome and
        # payload ride the polar_* hooks below.
        include Poetry::Charts::PolarFamily
        include Poetry::Charts::PolarFamily::SingleSeriesTooltip

        # The captured Series configs, forcing lazy slot evaluation.
        # @api private
        def series_entries
          pies? # force slot evaluation (slots evaluate lazily)
          @series_entries ||= []
        end

        # The center-label slot's captured config, forcing lazy slot
        # evaluation.
        # @api private
        def center_label_config
          center_label?
          @center_label_config
        end

        # -- geometry ---------------------------------------------------------

        # Memoized per SLOT (object identity), never per data_key: two rings
        # may share a data_key with different data:, and a key-keyed memo
        # would silently render the first ring's rows twice.
        # @api private
        def rows(entry)
          @rows ||= {}.compare_by_identity
          @rows[entry] ||= (entry.data || data || []).map { |row| row.to_h.transform_keys(&:to_s) }
        end

        # One computed slice: its sector geometry plus name, value, and
        # fill.
        Slice = Data.define(:index, :name, :value, :fill, :path, :mid_angle, :middle_radius, :label_point,
                            :inner, :outer, :start_angle, :end_angle)

        # Slot-identity memo, matching rows (a shared data_key must not
        # collapse two rings into one geometry).
        # @api private
        def slices(entry)
          @slices ||= {}.compare_by_identity
          @slices[entry] ||= begin
            entry_rows = rows(entry)
            values = entry_rows.map { |row| row[entry.data_key] }
            max = Polar.max_radius(plot[:width], plot[:height])
            inner = Polar.percent_value(entry.inner_radius, max, 0)
            outer = Polar.percent_value(entry.outer_radius, max, max * 0.8)

            Polar.pie_sectors(values, padding_angle: entry.padding_angle).each_with_index.filter_map do |sector, i|
              next if sector[:start_angle] == sector[:end_angle] && entry_rows.length != 1

              grown = entry.active_index == i ? outer + entry.active_grow : outer
              middle_radius = (inner + grown) / 2.0
              Slice.new(
                index: i,
                name: entry_rows[i][entry.name_key].to_s,
                value: sector[:value],
                fill: slice_fill(entry, entry_rows[i]),
                path: Polar.sector_path(cx: cx, cy: cy, inner_radius: inner, outer_radius: grown,
                                        start_angle: sector[:start_angle], end_angle: sector[:end_angle]),
                mid_angle: sector[:mid_angle],
                middle_radius: middle_radius,
                label_point: Polar.polar_to_cartesian(cx, cy, middle_radius, sector[:mid_angle]),
                inner: inner,
                outer: grown,
                start_angle: sector[:start_angle],
                end_angle: sector[:end_angle]
              )
            end
          end
        end

        # A slice's fill: the color_key row value (CSS-validated), else
        # the config color for its name, else the series color var.
        # @api private
        def slice_fill(entry, row)
          color = row[entry.color_key].to_s if entry.color_key
          if color.present?
            raise ArgumentError, "slice fill #{color.inspect} is not CSS-safe" unless color.match?(Config::COLOR)

            color
          else
            name = row[entry.name_key].to_s
            chart_config[name]&.color || "var(--color-#{entry.data_key})"
          end
        end

        # Named labels resolve through the config (raw "chrome" ->
        # "Chrome"), the same lookup the tooltip and legend already do.
        # @api private
        def slice_label(entry, slice)
          return slice.value.to_i.to_s unless entry.label_key

          raw = rows(entry)[slice.index][entry.label_key].to_s
          chart_config.label_for(raw, raw)
        end

        # -- the tooltip payload (polar shape) ---------------------------------

        # The SingleSeriesTooltip hooks: the FIRST pie's slices are the
        # items, anchored at their label points; values read that pie's
        # own rows.
        # @api private
        def polar_items(entry) = slices(entry)
        # Where the tooltip anchors on one slice.
        # @api private
        def polar_anchor(slice) = slice.label_point
        # The rows the tooltip values read from.
        # @api private
        def polar_value_rows(entry) = rows(entry)

        # ChartFamily#svg_label's chart-type lead-in.
        # @api private
        def svg_label_prefix = "Pie chart"

        private :center_label_config, :rows, :slices, :slice_fill, :slice_label, :polar_items
        private :polar_anchor, :polar_value_rows, :svg_label_prefix
      end
    end
  end
end
