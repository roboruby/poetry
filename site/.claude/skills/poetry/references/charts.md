# poetry chart components

Contracts generated from the charts registry. Chart data is
server-rendered; the `poetry_chart(type, ...)` shorthand takes the
chart type as its one positional argument.

## adapter_chart (`poetry_adapter_chart`)

Class: Poetry::Charts::AdapterChart::Component - BEM block `poetry-charts-adapter_chart`.
- `axes:` ()
- `config:` () - required
- `data:` () - required
- `engine:` (string) - required
- `id:` (string)
- `label:` (string)
- `series:` () - required
- `type:` (symbol) - one of area|bar|line|pie|radar|radial, required
- RULE: The adapter path takes series:/axes: ARGUMENTS (the closed spec), not slots.
- RULE: The host must register the engine first: registerChartAdapter(name, adapter) - poetry ships createChartJsAdapter(Chart) as the reference.
- RULE: The Container contract still applies: config colors, --chart tokens, dark mode.
- RULE: Prefer the default engine; adapters are for engine-specific needs (e.g. >10k points on canvas).

## area_chart (`poetry_area_chart`)

Class: Poetry::Charts::AreaChart::Component - BEM block `poetry-charts-area_chart`.
- `animate:` (boolean) - default true
- `animation_begin:` (integer) - default 0
- `animation_duration:` (integer) - default 1500
- `animation_easing:` (symbol) - default "ease"
- `config:` () - required
- `data:` () - required
- `height:` (integer) - default 360
- `id:` (string)
- `label:` (string)
- `live:` (boolean) - default false
- `margin:` ()
- `offset:` (symbol) - one of none|expand, default "none"
- `sync:` (string)
- `width:` (integer) - default 640
- `zoom:` (boolean) - default false
Slots: reference_lines (many; with_reference_line keywords: x:, y:, label:, stroke_dasharray: ONLY), reference_areas (many; with_reference_area keywords: x1:, x2:, y1:, y2:, label:, fill_opacity: ONLY), reference_dots (many; with_reference_dot keywords: x:, y:, r:, label: ONLY), brush (with_brush keywords: height: ONLY), areas (many; with_area keywords: data_key:, stack:, curve:, fill_opacity:, gradient:, stroke_width: ONLY), x_axis (with_x_axis keywords: data_key:, tick_formatter:, tick_margin: ONLY), y_axis (with_y_axis keywords: tick_count:, tick_formatter:, tick_margin: ONLY), grid (with_grid keywords: vertical:, horizontal: ONLY), legend, tooltip.
- RULE: Compose from slots: with_grid / with_x_axis(data_key:) / with_area(data_key:) / with_legend.
- RULE: Stack areas by giving them the same stack: id; offset: :expand makes the stack percent-based.
- RULE: Colors come from the config - never set fill/stroke on an area directly.
- RULE: gradient: true on an area gets the shadcn 5%/95% fade fill.
- RULE: Charts render complete on the server; the tooltip layer attaches separately.
- RULE: Entrance animation is on by default (recharts parity); animate: false for a static chart. Reduced-motion users always get the finished chart.

## bar_chart (`poetry_bar_chart`)

Class: Poetry::Charts::BarChart::Component - BEM block `poetry-charts-bar_chart`.
- `animate:` (boolean) - default true
- `animation_begin:` (integer) - default 0
- `animation_duration:` (integer) - default 400
- `animation_easing:` (symbol) - default "ease"
- `bar_category_gap:` (string) - default "10%"
- `bar_gap:` (integer) - default 4
- `config:` () - required
- `data:` () - required
- `height:` (integer) - default 360
- `id:` (string)
- `label:` (string)
- `live:` (boolean) - default false
- `margin:` ()
- `offset:` (symbol) - one of none|expand, default "none"
- `orientation:` (symbol) - one of vertical|horizontal, default "vertical"
- `sync:` (string)
- `width:` (integer) - default 640
- `zoom:` (boolean) - default false
Slots: reference_lines (many; with_reference_line keywords: x:, y:, label:, stroke_dasharray: ONLY), reference_areas (many; with_reference_area keywords: x1:, x2:, y1:, y2:, label:, fill_opacity: ONLY), reference_dots (many; with_reference_dot keywords: x:, y:, r:, label: ONLY), brush (with_brush keywords: height: ONLY), bars (many; with_bar keywords: data_key:, stack:, radius:, labels:, label_key:, color_key:, cell_fill:, active_index:, stroke_width:, error_key:, error_width: ONLY), x_axis (with_x_axis keywords: data_key:, tick_formatter:, tick_margin: ONLY), y_axis (with_y_axis keywords: data_key:, tick_count:, tick_formatter:, tick_margin: ONLY), grid (with_grid keywords: vertical:, horizontal: ONLY), legend, tooltip.
- RULE: Compose from slots: with_grid / with_x_axis(data_key:) / with_bar(data_key:) / with_legend.
- RULE: radius: 8 rounds all corners; stacked bars use arrays - [0,0,4,4] bottom bar, [4,4,0,0] top bar.
- RULE: Stack bars with the same stack: id; negatives automatically drop below the zero line.
- RULE: cell_fill: ->(row, value) { ... } colors bars per datum (validated CSS-safe); color_key: reads a row key.
- RULE: active_index: highlights one bar (fill-opacity 0.8 + dashed stroke - the active block look).
- RULE: Entrance animation is on by default (recharts parity); animate: false for a static chart. Reduced-motion users always get the finished chart.

## composed_chart (`poetry_composed_chart`)

Class: Poetry::Charts::ComposedChart::Component - BEM block `poetry-charts-composed_chart`.
- `animate:` (boolean) - default true
- `animation_begin:` (integer) - default 0
- `animation_duration:` (integer) - default 1500
- `animation_easing:` (symbol) - default "ease"
- `bar_category_gap:` (string) - default "10%"
- `bar_gap:` (integer) - default 4
- `config:` () - required
- `data:` () - required
- `height:` (integer) - default 360
- `id:` (string)
- `label:` (string)
- `margin:` ()
- `sync:` (string)
- `width:` (integer) - default 640
Slots: reference_lines (many; with_reference_line keywords: x:, y:, label:, stroke_dasharray: ONLY), reference_areas (many; with_reference_area keywords: x1:, x2:, y1:, y2:, label:, fill_opacity: ONLY), reference_dots (many; with_reference_dot keywords: x:, y:, r:, label: ONLY), areas (many; with_area keywords: data_key:, stack:, curve:, fill_opacity:, gradient:, stroke_width: ONLY), bars (many; with_bar keywords: data_key:, stack:, radius: ONLY), lines (many; with_line keywords: data_key:, curve:, stroke_width:, dots:, dot_radius: ONLY), x_axis (with_x_axis keywords: data_key:, tick_formatter:, tick_margin: ONLY), y_axis (with_y_axis keywords: tick_count:, tick_formatter:, tick_margin: ONLY), grid (with_grid keywords: vertical:, horizontal: ONLY), legend, tooltip.
- RULE: Mix marks freely: with_area / with_bar / with_line - declaration order is paint order.
- RULE: All marks share the x band and ONE y domain; lines and areas ride the band centers.
- RULE: stack: ids only combine within the same mark type (a bar stack never joins an area stack).
- RULE: Colors come from the config - never set fill/stroke on a mark directly.
- RULE: Entrance animation is on by default; each mark uses its own recharts mechanism.

## container (`poetry_container`)

Class: Poetry::Charts::Container::Component - BEM block `poetry-charts-container`.
- `config:` () - required
- `id:` (string)
- RULE: Every chart lives inside poetry_chart_container(config:) - the config maps series keys to labels/colors.
- RULE: Reference series colors as var(--color-<key>); never hard-code a color in chart markup.
- RULE: Config colors point at theme tokens (var(--chart-1..5)) or use theme: { light:, dark: } maps.
- RULE: Give charts an explicit id: when the page renders more than one of the same chart.

## legend_content (`poetry_legend_content`)

Class: Poetry::Charts::LegendContent::Component - BEM block `poetry-charts-legend_content`.
- `align:` (symbol) - one of top|bottom, default "bottom", required
- `config:` () - required
- `hide_icon:` (boolean) - default false
- `items:` ()
- `toggle:` (boolean) - default false
- RULE: The legend derives from the chart config by default - omit items: unless slices differ from series.
- RULE: align: :top pads below (pb-3), :bottom (default) pads above (pt-3) - matching the chart edge it sits on.

## line_chart (`poetry_line_chart`)

Class: Poetry::Charts::LineChart::Component - BEM block `poetry-charts-line_chart`.
- `animate:` (boolean) - default true
- `animation_begin:` (integer) - default 0
- `animation_duration:` (integer) - default 1500
- `animation_easing:` (symbol) - default "ease"
- `config:` () - required
- `data:` () - required
- `height:` (integer) - default 360
- `id:` (string)
- `label:` (string)
- `live:` (boolean) - default false
- `margin:` ()
- `sync:` (string)
- `width:` (integer) - default 640
- `zoom:` (boolean) - default false
Slots: reference_lines (many; with_reference_line keywords: x:, y:, label:, stroke_dasharray: ONLY), reference_areas (many; with_reference_area keywords: x1:, x2:, y1:, y2:, label:, fill_opacity: ONLY), reference_dots (many; with_reference_dot keywords: x:, y:, r:, label: ONLY), brush (with_brush keywords: height: ONLY), lines (many; with_line keywords: data_key:, curve:, stroke_width:, dots:, dot_radius:, dot_color_key:, labels:, error_key:, error_width: ONLY), x_axis (with_x_axis keywords: data_key:, tick_formatter:, tick_margin: ONLY), y_axis (with_y_axis keywords: tick_count:, tick_formatter:, tick_margin: ONLY), grid (with_grid keywords: vertical:, horizontal: ONLY), legend, tooltip.
- RULE: Compose from slots: with_grid / with_x_axis(data_key:) / with_line(data_key:) / with_legend.
- RULE: Lines default to stroke-width 2 and NO dots (the shadcn block look); dots: true adds them.
- RULE: dot_color_key: reads a per-row data key for per-point dot colors (the dots-colors block).
- RULE: labels: true stamps each value above its point; give the chart margin top when using it.
- RULE: Colors come from the config - never set stroke on a line directly.
- RULE: Entrance animation is on by default (recharts parity); animate: false for a static chart. Reduced-motion users always get the finished chart.

## pie_chart (`poetry_pie_chart`)

Class: Poetry::Charts::PieChart::Component - BEM block `poetry-charts-pie_chart`.
- `animate:` (boolean) - default true
- `animation_begin:` (integer) - default 400
- `animation_duration:` (integer) - default 1500
- `animation_easing:` (symbol) - default "ease"
- `config:` () - required
- `data:` ()
- `height:` (integer) - default 250
- `id:` (string)
- `label:` (string)
- `margin:` ()
- `sync:` (string)
- `width:` (integer) - default 250
Slots: pies (many; with_pie keywords: data_key:, data:, name_key:, inner_radius:, outer_radius:, padding_angle:, stroke_width:, color_key:, labels:, label_key:, active_index:, active_grow: ONLY), center_label (with_center_label keywords: title:, subtitle: ONLY), legend, tooltip.
- RULE: Rows carry their slice color in a fill key (var(--color-<name>)); the config maps names to labels.
- RULE: inner_radius: 60 makes the donut; with_center_label(title:, subtitle:) fills the hole.
- RULE: Stacked pies: two with_pie slots with their own data: and non-overlapping radii.
- RULE: active_index: pops one slice out by 10px (the donut-active look).
- RULE: The tooltip walks slices by hover AND arrow keys (role=application when attached).
- RULE: Entrance animation is on by default (recharts parity); animate: false for a static chart. Reduced-motion users always get the finished chart.

## radar_chart (`poetry_radar_chart`)

Class: Poetry::Charts::RadarChart::Component - BEM block `poetry-charts-radar_chart`.
- `animate:` (boolean) - default true
- `animation_begin:` (integer) - default 0
- `animation_duration:` (integer) - default 1500
- `animation_easing:` (symbol) - default "ease"
- `config:` () - required
- `data:` () - required
- `height:` (integer) - default 250
- `id:` (string)
- `label:` (string)
- `margin:` ()
- `outer_radius:` () - default "80%"
- `sync:` (string)
- `width:` (integer) - default 250
Slots: radars (many; with_radar keywords: data_key:, fill_opacity:, stroke_width:, dots:, dot_radius: ONLY), angle_axis (with_angle_axis keywords: data_key:, tick_formatter: ONLY), grid (with_grid keywords: type:, radial_lines:, fill:, opacity: ONLY), legend, tooltip.
- RULE: Compose from slots: with_angle_axis(data_key:) / with_grid / with_radar(data_key:) / with_legend.
- RULE: Radars fill at 0.6 opacity by default; lines-only = fill_opacity: 0, stroke_width: 2.
- RULE: with_grid type: :circle swaps polygons for circles; fill: :desktop tints every grid ring (opacity 0.2, compounding toward the center - the grid-fill look).
- RULE: dots: true marks every vertex (r 4, solid).
- RULE: Colors come from the config - never set fill/stroke on a radar directly.
- RULE: Entrance animation is on by default (recharts parity); animate: false for a static chart. Reduced-motion users always get the finished chart.

## radial_bar_chart (`poetry_radial_bar_chart`)

Class: Poetry::Charts::RadialBarChart::Component - BEM block `poetry-charts-radial_bar_chart`.
- `animate:` (boolean) - default true
- `animation_begin:` (integer) - default 0
- `animation_duration:` (integer) - default 1500
- `animation_easing:` (symbol) - default "ease"
- `config:` () - required
- `data:` () - required
- `end_angle:` (integer) - default 360
- `height:` (integer) - default 250
- `id:` (string)
- `inner_radius:` () - default "20%"
- `label:` (string)
- `margin:` ()
- `max_value:` ()
- `name_key:` (string) - default "name"
- `outer_radius:` () - default "80%"
- `start_angle:` (integer) - default 0
- `sync:` (string)
- `width:` (integer) - default 250
Slots: radial_bars (many; with_radial_bar keywords: data_key:, stack:, background:, corner_radius:, color_key:, labels:, label_key: ONLY), polar_grid (with_polar_grid keywords: radii:, fills:, radial_lines: ONLY), center_label (with_center_label keywords: title:, subtitle:, compact: ONLY), legend, tooltip.
- RULE: One ring per data row; rows carry their color in a fill key (var(--color-<name>)).
- RULE: background: true draws the muted track ring behind each bar (the gauge look).
- RULE: Stack two radial bars with the same stack: id - they share the ring and stack by ANGLE.
- RULE: corner_radius rounds the arc ends (10 on a 10px ring = full pill caps).
- RULE: with_polar_grid(radii:, fills:) draws the shape/text blocks' disc track; with_center_label fills the middle.
- RULE: Entrance animation is on by default (recharts parity); animate: false for a static chart. Reduced-motion users always get the finished chart.

## scatter_chart (`poetry_scatter_chart`)

Class: Poetry::Charts::ScatterChart::Component - BEM block `poetry-charts-scatter_chart`.
- `animate:` (boolean) - default true
- `animation_begin:` (integer) - default 0
- `animation_duration:` (integer) - default 400
- `animation_easing:` (symbol) - default "linear"
- `config:` () - required
- `data:` ()
- `height:` (integer) - default 360
- `id:` (string)
- `label:` (string)
- `margin:` ()
- `sync:` (string)
- `width:` (integer) - default 640
Slots: reference_lines (many; with_reference_line keywords: x:, y:, label:, stroke_dasharray: ONLY), reference_areas (many; with_reference_area keywords: x1:, x2:, y1:, y2:, label:, fill_opacity: ONLY), reference_dots (many; with_reference_dot keywords: x:, y:, r:, label: ONLY), scatters (many; with_scatter keywords: key:, data:, error_key:, error_width: ONLY), x_axis (with_x_axis keywords: data_key:, tick_count:, tick_margin:, name: ONLY), y_axis (with_y_axis keywords: data_key:, tick_count:, tick_margin:, name: ONLY), z_axis (with_z_axis keywords: data_key:, range: ONLY), grid (with_grid keywords: vertical:, horizontal: ONLY), legend, tooltip.
- RULE: Both axes are numeric: with_x_axis(data_key:) / with_y_axis(data_key:) name the row keys to plot.
- RULE: with_scatter(key:) colors points var(--color-<key>); data: gives a series its own rows.
- RULE: with_z_axis(data_key:, range: [64, 144]) sizes points by a third dimension - the range is marker AREA in px2 (recharts ZAxis).
- RULE: The tooltip hits per point and shows the x/y(/z) values with the series color.
- RULE: Entrance animation is on by default (recharts Scatter: 400ms linear); animate: false for a static chart.

## tooltip_content (`poetry_tooltip_content`)

Class: Poetry::Charts::TooltipContent::Component - BEM block `poetry-charts-tooltip_content`.
- `config:` () - required
- `hide_indicator:` (boolean) - default false
- `hide_label:` (boolean) - default false
- `indicator:` (symbol) - one of dot|line|dashed, default "dot"
- `items:` () - required
- `label:` (string)
- RULE: Tooltip rows resolve names/colors through the chart config - pass key:, not a display string.
- RULE: indicator: :dot (default) | :line | :dashed matches the shadcn variants.
- RULE: Numeric values render delimited (1,234) in the mono tabular column automatically.

## tooltip_layer (`poetry_tooltip_layer`)

Class: Poetry::Charts::TooltipLayer::Component - BEM block `poetry-charts-tooltip_layer`.
- `config:` () - required
- `hide_indicator:` (boolean) - default false
- `hide_label:` (boolean) - default false
- `indicator:` (symbol) - default "dot"
- `series_keys:` () - required

