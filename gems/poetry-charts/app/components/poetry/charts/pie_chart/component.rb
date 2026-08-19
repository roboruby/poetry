# frozen_string_literal: true

module Poetry
  module Charts
    module PieChart
      # The Pie chart family (shadcn PieChart, 11 blocks): recharts' own
      # polar math (Polar module), server-rendered sectors. Slices color
      # from their row's fill key (the upstream data convention), the donut
      # hole comes from inner_radius, stacked pies nest two rings with their
      # own data, and the center label (donut-text) is plain SVG text.
      # The 250x250 viewBox mirrors the shadcn blocks' aspect-square
      # max-h-[250px] canvas, so recharts' absolute-px radii (innerRadius
      # 60, outerRadius+10 pop-outs) mean the identical proportion here.
      # Slices meet flush by default (the current recharts render);
      # stroke_width: N opts back into var(--background) separators -
      # recharts' #fff would break in dark mode.
      #
      #   <%= poetry_chart :pie, data: browsers, config: config do |c| %>
      #     <% c.with_pie data_key: :visitors, name_key: :browser, inner_radius: 60 %>
      #     <% c.with_tooltip %>
      #   <% end %>
      class Component < Poetry::Core::Component
        include Poetry::Charts::TooltipWiring
        include Poetry::Charts::Motion

        AGENT_RULES = [
          "Rows carry their slice color in a fill key (var(--color-<name>)); the config maps names to labels.",
          "inner_radius: 60 makes the donut; with_center_label(title:, subtitle:) fills the hole.",
          "Stacked pies: two with_pie slots with their own data: and non-overlapping radii.",
          "active_index: pops one slice out by 10px (the donut-active look).",
          "The tooltip walks slices by hover AND arrow keys (role=application when attached).",
          "Entrance animation is on by default (recharts parity); animate: false for a static chart. " \
          "Reduced-motion users always get the finished chart."
        ].freeze

        Series = Data.define(:data, :data_key, :name_key, :inner_radius, :outer_radius,
                             :padding_angle, :stroke_width, :color_key, :labels, :label_key,
                             :active_index, :active_grow)

        option :data, ActiveModel::Type::Value.new
        option :config, ActiveModel::Type::Value.new, required: true
        option :id, :string
        option :width, :integer, default: 250
        option :height, :integer, default: 250
        option :margin, ActiveModel::Type::Value.new
        option :label, :string

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

        renders_many :pies, lambda { |data_key:, data: nil, name_key: :name, inner_radius: 0,
                                      outer_radius: "80%", padding_angle: 0, stroke_width: 0,
                                      color_key: :fill, labels: nil, label_key: nil,
                                      active_index: nil, active_grow: 10|
          (@series_entries ||= []) << Series.new(data: data, data_key: data_key.to_s, name_key: name_key.to_s,
                                                 inner_radius:, outer_radius:, padding_angle:, stroke_width:,
                                                 color_key: color_key&.to_s, labels: labels&.to_sym,
                                                 label_key: label_key&.to_s, active_index:, active_grow:)
          nil
        }
        # ActiveSupport singularizes "pies" to "py" - give the grammar its
        # real name.
        alias with_pie with_py

        renders_one :center_label, lambda { |title:, subtitle: nil|
          @center_label_config = { title: title, subtitle: subtitle }
          nil
        }

        renders_one :legend, lambda { |**options|
          @legend_config = options
          nil
        }

        renders_one :tooltip, lambda { |**options|
          @tooltip_config = { hide_label: true }.merge(options)
          nil
        }

        def series_entries
          pies? # force slot evaluation (the N8 lazy-slot lesson)
          @series_entries ||= []
        end

        def center_label_config
          center_label?
          @center_label_config
        end

        def chart_config
          @chart_config ||= Poetry::Charts::Config.wrap(config)
        end

        # -- geometry ---------------------------------------------------------

        MARGIN = { top: 5, right: 5, bottom: 5, left: 5 }.freeze

        def plot
          @plot ||= begin
            m = MARGIN.merge((margin || {}).to_h.symbolize_keys)
            { left: m[:left].to_f, top: m[:top].to_f,
              width: width - m[:left] - m[:right], height: height - m[:top] - m[:bottom] }
          end
        end

        def cx = plot[:left] + (plot[:width] / 2.0)
        def cy = plot[:top] + (plot[:height] / 2.0)

        def rows(entry)
          @rows ||= {}
          @rows[entry.data_key] ||= (entry.data || data || []).map { |row| row.to_h.transform_keys(&:to_s) }
        end

        Slice = Data.define(:index, :name, :value, :fill, :path, :mid_angle, :middle_radius, :label_point,
                            :inner, :outer, :start_angle, :end_angle)

        def slices(entry)
          @slices ||= {}
          @slices[entry.data_key] ||= begin
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

        # Named labels resolve through the config (raw "chrome" -> "Chrome"),
        # the same lookup the tooltip and legend already do - upstream's
        # LabelList formatter in one place.
        def slice_label(entry, slice)
          return slice.value.to_i.to_s unless entry.label_key

          raw = rows(entry)[slice.index][entry.label_key].to_s
          chart_config.label_for(raw, raw)
        end

        # -- the tooltip payload (polar shape) ---------------------------------

        # The FIRST pie drives the tooltip (stacked pies: document); slices
        # carry per-index names/colors so the single chrome row retints.
        def coordinates_json
          entry = series_entries.first
          return "{}" unless entry

          primary = slices(entry)
          {
            "layout" => "polar",
            "categories" => primary.map { |s| chart_config.label_for(s.name, s.name) },
            "names" => primary.map { |s| chart_config.label_for(s.name, s.name) },
            "colors" => primary.map(&:fill),
            "anchors" => primary.map { |s| s.label_point.map { |v| v.round(2) } },
            "values" => { entry.data_key => rows(entry).map do |row|
              Poetry::Charts.display_value(row[entry.data_key])
            end }
          }.to_json
        end

        def chart_id
          @chart_id ||= (dom_id_token(id) ? "chart-#{dom_id_token(id)}" : poetry_instance_id("chart"))
        end

        def svg_label
          label.presence || "Pie chart: #{chart_config.entries.map { |e| e.label || e.key }.join(", ")}"
        end

        # Pie slices are hit by pointerover on the marked sector, not
        # bisect - the svg gains the enter action after the module's
        # pointer/keyboard set.
        use_stimulus do
          on :svg do
            controller(TooltipWiring::CONTROLLER, if: :tooltip?) { action :enter, on: :pointerover }
          end
        end

        def tooltip_layer_component
          TooltipLayer::Component.new(
            config: chart_config,
            series_keys: [series_entries.first&.data_key].compact,
            indicator: tooltip_config.fetch(:indicator, :dot),
            hide_label: tooltip_config.fetch(:hide_label, true),
            hide_indicator: tooltip_config.fetch(:hide_indicator, false)
          )
        end

        def fnum(value)
          Geometry.js_number((value * 100).round / 100.0)
        end
      end
    end
  end
end
