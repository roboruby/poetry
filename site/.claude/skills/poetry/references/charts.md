# poetry chart components

Contracts generated from the charts registry. Chart data is
server-rendered; the `poetry_chart(type, ...)` shorthand takes the
chart type as its one positional argument.

## adapter_chart (`poetry_adapter_chart`)

The bring-your-own-engine path: a themed mount and chart-spec JSON for a client library (Chart.js, etc.) to draw, instead of poetry's server-side SVG.

Class: Poetry::Charts::AdapterChart::Component - BEM block `poetry-charts-adapter_chart`.
- `axes:` () - The axis config ({ x:, y: } hashes), also spec-carried.
- `config:` () - required - The series config - key => { label:, color: } - naming and coloring every series.
- `data:` () - required - The rows to plot, serialized into the spec.
- `engine:` (string) - required - The registered adapter's name; the controller hands it the mount and the spec.
- `id:` (string) - Explicit DOM id token, stable across renders; otherwise the chart gets a unique per-render id.
- `label:` (string) - Accessible name for the mount; defaults to one built from the type and engine.
- `series:` () - required - The series list ({ data_key:, ... } hashes) - the closed spec's replacement for slots.
- `type:` (symbol) - one of area|bar|line|pie|radar|radial, required - The chart type carried in the spec (see Spec::TYPES).
- PART `chart-adapter-mount` - The engine's drawing surface (role=img carrying the accessible label) - the registered adapter renders into it
- PART `chart-spec` - The frozen chart-spec v1, served as JSON in an application/json script for the adapter to consume
- WIRING frame: `poetry--charts--adapter` registers; values engine
- WIRING mount: `poetry--charts--adapter` targets mount
- WIRING spec: `poetry--charts--adapter` targets spec
- RULE: The adapter path takes series:/axes: ARGUMENTS (the closed spec), not slots.
- RULE: The host must register the engine first: registerChartAdapter(name, adapter) - poetry ships createChartJsAdapter(Chart) as the reference.
- RULE: The Container contract still applies: config colors, --chart tokens, dark mode.
- RULE: Prefer the default engine; adapters are for engine-specific needs (e.g. >10k points on canvas).

## area_chart (`poetry_area_chart`)

An area chart for volume or cumulative totals over a continuous axis.

Class: Poetry::Charts::AreaChart::Component - BEM block `poetry-charts-area_chart`.
- `animate:` (boolean) - default true - Entrance animation switch - reduced-motion users always get the finished chart regardless.
- `animation_begin:` (integer) - default 0 - Pre-animation hold in milliseconds.
- `animation_duration:` (integer) - default 1500 - Entrance/morph duration in milliseconds.
- `animation_easing:` (symbol) - default "ease" - Animation easing keyword (see EASINGS).
- `config:` () - required - The series config - key => { label:, color: } - naming and coloring every series.
- `data:` () - required - The rows to plot: an array of hashes, one per x category.
- `height:` (integer) - default 360 - ViewBox height in pixels.
- `id:` (string) - Explicit DOM id token, stable across renders; otherwise the chart gets a unique per-render id.
- `label:` (string) - Accessible name for the chart SVG; defaults to one built from the configured series.
- `live:` (boolean) - default false - Embeds the {spec, frame} payload so the client renderer can recompute geometry when data changes without a server round-trip.
- `margin:` () - Plot margin overrides ({ top:, right:, bottom:, left: }), merged over the defaults.
- `offset:` (symbol) - one of none|expand, default "none" - Stack baseline mode - :expand normalizes each stack to percentages.
- `sync:` (string)
- `width:` (integer) - default 640 - ViewBox width in pixels; the rendered chart scales to its container.
- `zoom:` (boolean) - default false - Drag-to-zoom on the plot; slices the data client-side, so it needs live: true.
Slots: reference_lines (many; with_reference_line keywords: x:, y:, label:, stroke_dasharray: ONLY), reference_areas (many; with_reference_area keywords: x1:, x2:, y1:, y2:, label:, fill_opacity: ONLY), reference_dots (many; with_reference_dot keywords: x:, y:, r:, label: ONLY), brush (The brush strip below the x axis - drag its window to slice the visible range; needs live: true.; with_brush keywords: height: ONLY), areas (An area series bound to data_key:. Areas sharing a stack: id pile up; gradient: true fades the fill; curve: picks the interpolation.; many; with_area keywords: data_key:, stack:, curve:, fill_opacity:, gradient:, stroke_width: ONLY), x_axis (with_x_axis keywords: data_key:, tick_formatter:, tick_margin: ONLY), y_axis (The value axis: tick_count: sets how many ticks show; tick_formatter: reshapes each label; tick_margin: pads it.; with_y_axis keywords: tick_count:, tick_formatter:, tick_margin: ONLY), grid (with_grid keywords: vertical:, horizontal: ONLY), legend, tooltip.
- PART `chart-brush` - The brush strip group (with_brush): track + window + two handles below the x axis
- PART `chart-brush-track` - The full-width brush rail
- PART `chart-brush-window` - The selected-range rect the drag moves
- PART `chart-brush-handle` - One draggable window edge | states: data-edge=start|end (always - which edge)
- PART `chart-zoom-selection` - The zoom drag-selection overlay (zoom: true), hidden until a drag starts
- PART `chart-live-payload` - The embedded {spec, frame} JSON the live renderer recomputes geometry from
- PART `chart-svg` - The chart canvas (<svg>) - server-computed geometry in a fixed viewBox; role=img, or the focusable role=application accessibilityLayer when the tooltip attaches | states: data-animate (present when animate (the default) - the motion stylesheet and controller key the entrance off it); data-motion=entrance|morph|settled (runtime - the motion rig stamps the animation lifecycle (entrance/morph, then settled)) | vars: --poetry-motion-duration (the entrance/morph duration (animation_duration, ms)); --poetry-motion-easing (the animation easing keyword (animation_easing)); --poetry-motion-delay (the pre-animation hold (animation_begin, ms))
- PART `chart-motion-reveal` - The entrance clipPath rect (the ported area reveal) - the motion stylesheet scales it 0 -> 1; only when animate
- PART `chart-grid` - The gridline group (with_grid) - horizontal and/or vertical rules across the plot
- PART `chart-cursor` - The hover cursor, hidden until the tooltip controller positions and reveals it at the active index - a vertical rule or a translucent band rect (bar charts)
- PART `chart-areas` - The area-mark group - a fill path plus top-curve stroke per series, clipped by the reveal rect while animating
- PART `chart-area` - One series' fill path (var(--color-<key>) or its gradient) | states: data-key (the series key)
- PART `chart-area-stroke` - One series' top-curve stroke path (the source strokes the curve, never the area outline) | states: data-key (the series key)
- PART `chart-active-dots` - The hover-marker group (with_tooltip) - pre-rendered hidden circles for every series x index
- PART `chart-active-dot` - One hover marker - display=none until the tooltip controller reveals the active index's dot | states: data-key (the series key); data-index (the datum index); data-active (runtime - rides the marker while its index is the active one)
- PART `chart-x-axis` - The x-axis tick-label group (with_x_axis)
- PART `chart-y-axis` - The y-axis tick-label group (with_y_axis)
- PART `chart-coordinates` - The embedded per-index geometry payload (<script type=application/json>) the tooltip controller reads - zero chart math in the browser
- WIRING frame: `poetry--charts--tooltip` (if tooltip?) registers; values sync (if) | `poetry--charts--motion` (if animate?) registers | `poetry--charts--live` (if live?) registers; actions receive on poetry-chart:update | `poetry--charts--tooltip` (if) actions refresh on poetry--charts--live:updated | `poetry--charts--window` (if window_features?) registers; values zoom, plot, brush (if)
- WIRING svg: `poetry--charts--tooltip` (if tooltip?) actions move on pointermove, leave on pointerleave, focus on focus, blur on blur, keydown on keydown; targets svg | `poetry--charts--window` (if zoom?) actions startZoom on pointerdown, reset on dblclick
- WIRING coordinates: `poetry--charts--tooltip` (if tooltip?) targets data
- WIRING tooltip_layer: `poetry--charts--tooltip` (if tooltip?) targets tooltip
- WIRING live_payload: `poetry--charts--live` targets payload
- WIRING brush: `poetry--charts--window` (if) actions startBrush on pointerdown
- RULE: Compose from slots: with_grid / with_x_axis(data_key:) / with_area(data_key:) / with_legend.
- RULE: Stack areas by giving them the same stack: id; offset: :expand makes the stack percent-based.
- RULE: Colors come from the config - never set fill/stroke on an area directly.
- RULE: gradient: true on an area gets the source's 5%/95% fade fill.
- RULE: Charts render complete on the server; the tooltip layer attaches separately.
- RULE: Entrance animation is on by default (source parity); animate: false for a static chart. Reduced-motion users always get the finished chart.

## bar_chart (`poetry_bar_chart`)

A bar chart for comparing values across categories.

Class: Poetry::Charts::BarChart::Component - BEM block `poetry-charts-bar_chart`.
- `animate:` (boolean) - default true - Entrance animation switch - reduced-motion users always get the finished chart regardless.
- `animation_begin:` (integer) - default 0 - Pre-animation hold in milliseconds.
- `animation_duration:` (integer) - default 400 - Entrance/morph duration in milliseconds.
- `animation_easing:` (symbol) - default "ease" - Animation easing keyword (see EASINGS).
- `bar_category_gap:` (string) - default "10%" - Band trim on each side: a percent string of the band width, or a bare pixel number.
- `bar_gap:` (integer) - default 4 - Pixels between side-by-side bars inside one category band.
- `config:` () - required - The series config - key => { label:, color: } - naming and coloring every series.
- `data:` () - required - The rows to plot: an array of hashes, one per category.
- `height:` (integer) - default 360 - ViewBox height in pixels.
- `id:` (string) - Explicit DOM id token, stable across renders; otherwise the chart gets a unique per-render id.
- `label:` (string) - Accessible name for the chart SVG; defaults to one built from the configured series.
- `live:` (boolean) - default false - Embeds the {spec, frame} payload so the client renderer can recompute geometry when data changes without a server round-trip.
- `margin:` () - Plot margin overrides ({ top:, right:, bottom:, left: }), merged over the defaults.
- `offset:` (symbol) - one of none|expand, default "none" - Stack baseline mode - :expand normalizes each stack to percentages.
- `orientation:` (symbol) - one of vertical|horizontal, default "vertical" - :vertical = columns (the default); :horizontal = bars growing rightward - the category axis moves to the Y side (with_y_axis data_key:) and the numeric axis hides.
- `sync:` (string)
- `width:` (integer) - default 640 - ViewBox width in pixels; the rendered chart scales to its container.
- `zoom:` (boolean) - default false - Drag-to-zoom on the plot; slices the data client-side, so it needs live: true.
Slots: reference_lines (many; with_reference_line keywords: x:, y:, label:, stroke_dasharray: ONLY), reference_areas (many; with_reference_area keywords: x1:, x2:, y1:, y2:, label:, fill_opacity: ONLY), reference_dots (many; with_reference_dot keywords: x:, y:, r:, label: ONLY), brush (The brush strip below the x axis - drag its window to slice the visible range; needs live: true.; with_brush keywords: height: ONLY), bars (A bar series bound to data_key:. Bars sharing a stack: id pile up; radius: rounds corners; labels:/label_key: stamp values; color_key:/cell_fill: color per cell; active_index: highlights one bar; error_key: adds whiskers.; many; with_bar keywords: data_key:, stack:, radius:, labels:, label_key:, color_key:, cell_fill:, active_index:, stroke_width:, error_key:, error_width: ONLY), x_axis (with_x_axis keywords: data_key:, tick_formatter:, tick_margin: ONLY), y_axis (The y axis: data_key: makes it the category axis (horizontal orientation); tick_count:/tick_formatter:/tick_margin: as on the x axis.; with_y_axis keywords: data_key:, tick_count:, tick_formatter:, tick_margin: ONLY), grid (with_grid keywords: vertical:, horizontal: ONLY), legend, tooltip.
- PART `chart-brush` - The brush strip group (with_brush): track + window + two handles below the x axis
- PART `chart-brush-track` - The full-width brush rail
- PART `chart-brush-window` - The selected-range rect the drag moves
- PART `chart-brush-handle` - One draggable window edge | states: data-edge=start|end (always - which edge)
- PART `chart-zoom-selection` - The zoom drag-selection overlay (zoom: true), hidden until a drag starts
- PART `chart-live-payload` - The embedded {spec, frame} JSON the live renderer recomputes geometry from
- PART `chart-svg` - The chart canvas (<svg>) - server-computed geometry in a fixed viewBox; role=img, or the focusable role=application accessibilityLayer when the tooltip attaches | states: data-animate (present when animate (the default) - the motion stylesheet and controller key the entrance off it); data-motion=entrance|morph|settled (runtime - the motion rig stamps the animation lifecycle (entrance/morph, then settled)) | vars: --poetry-motion-duration (the entrance/morph duration (animation_duration, ms)); --poetry-motion-easing (the animation easing keyword (animation_easing)); --poetry-motion-delay (the pre-animation hold (animation_begin, ms))
- PART `chart-grid` - The gridline group (with_grid) - horizontal and/or vertical rules across the plot
- PART `chart-cursor` - The hover cursor, hidden until the tooltip controller positions and reveals it at the active index - a vertical rule or a translucent band rect (bar charts)
- PART `chart-bars` - The bar-mark group wrapping every series
- PART `chart-bar-series` - One series' bar group | states: data-key (the series key)
- PART `chart-bar` - One bar cell (a per-corner rounded-rect path) | states: data-key (the series key); data-index (the datum index); data-active (the highlighted cell - server-rendered from active_index:, and the tooltip controller marks the hovered index at runtime); data-motion-origin=bottom|top|left|right (when animate - the zero edge the entrance grows from)
- PART `chart-labels` - One series' value-label group (labels: true) | states: data-key (the series key)
- PART `chart-x-axis` - The x-axis tick-label group (with_x_axis)
- PART `chart-y-axis` - The y-axis tick-label group (with_y_axis)
- PART `chart-coordinates` - The embedded per-index geometry payload (<script type=application/json>) the tooltip controller reads - zero chart math in the browser
- WIRING frame: `poetry--charts--tooltip` (if tooltip?) registers; values sync (if) | `poetry--charts--motion` (if animate?) registers | `poetry--charts--live` (if live?) registers; actions receive on poetry-chart:update | `poetry--charts--tooltip` (if) actions refresh on poetry--charts--live:updated | `poetry--charts--window` (if window_features?) registers; values zoom, plot, brush (if)
- WIRING svg: `poetry--charts--tooltip` (if tooltip?) actions move on pointermove, leave on pointerleave, focus on focus, blur on blur, keydown on keydown; targets svg | `poetry--charts--window` (if zoom?) actions startZoom on pointerdown, reset on dblclick
- WIRING coordinates: `poetry--charts--tooltip` (if tooltip?) targets data
- WIRING tooltip_layer: `poetry--charts--tooltip` (if tooltip?) targets tooltip
- WIRING live_payload: `poetry--charts--live` targets payload
- WIRING brush: `poetry--charts--window` (if) actions startBrush on pointerdown
- RULE: Compose from slots: with_grid / with_x_axis(data_key:) / with_bar(data_key:) / with_legend.
- RULE: radius: 8 rounds all corners; stacked bars use arrays - [0,0,4,4] bottom bar, [4,4,0,0] top bar.
- RULE: Stack bars with the same stack: id; negatives automatically drop below the zero line.
- RULE: cell_fill: ->(row, value) { ... } colors bars per datum (validated CSS-safe); color_key: reads a row key.
- RULE: active_index: highlights one bar (fill-opacity 0.8 + dashed stroke - the active block look).
- RULE: Entrance animation is on by default (source parity); animate: false for a static chart. Reduced-motion users always get the finished chart.

## composed_chart (`poetry_composed_chart`)

A composed chart layering bars, lines, and areas on shared axes.

Class: Poetry::Charts::ComposedChart::Component - BEM block `poetry-charts-composed_chart`.
- `animate:` (boolean) - default true - Entrance animation switch - reduced-motion users always get the finished chart regardless.
- `animation_begin:` (integer) - default 0 - Pre-animation hold in milliseconds.
- `animation_duration:` (integer) - default 1500 - Entrance/morph duration in milliseconds.
- `animation_easing:` (symbol) - default "ease" - Animation easing keyword (see EASINGS).
- `bar_category_gap:` (string) - default "10%" - Band trim on each side: a percent string of the band width, or a bare pixel number.
- `bar_gap:` (integer) - default 4 - Pixels between side-by-side bars inside one category band.
- `config:` () - required - The series config - key => { label:, color: } - naming and coloring every series.
- `data:` () - required - The rows to plot: an array of hashes, one per x category.
- `height:` (integer) - default 360 - ViewBox height in pixels.
- `id:` (string) - Explicit DOM id token, stable across renders; otherwise the chart gets a unique per-render id.
- `label:` (string) - Accessible name for the chart SVG; defaults to one built from the configured series.
- `margin:` () - Plot margin overrides ({ top:, right:, bottom:, left: }), merged over the defaults.
- `sync:` (string)
- `width:` (integer) - default 640 - ViewBox width in pixels; the rendered chart scales to its container.
Slots: reference_lines (many; with_reference_line keywords: x:, y:, label:, stroke_dasharray: ONLY), reference_areas (many; with_reference_area keywords: x1:, x2:, y1:, y2:, label:, fill_opacity: ONLY), reference_dots (many; with_reference_dot keywords: x:, y:, r:, label: ONLY), areas (An area mark bound to data_key:; areas sharing a stack: id pile up (area stacks never join bar stacks).; many; with_area keywords: data_key:, stack:, curve:, fill_opacity:, gradient:, stroke_width: ONLY), bars (A bar mark bound to data_key:; radius: rounds corners; bars sharing a stack: id pile up within the bar marks.; many; with_bar keywords: data_key:, stack:, radius: ONLY), lines (A line mark bound to data_key:; dots: marks each point.; many; with_line keywords: data_key:, curve:, stroke_width:, dots:, dot_radius: ONLY), x_axis (with_x_axis keywords: data_key:, tick_formatter:, tick_margin: ONLY), y_axis (The value axis: tick_count: sets how many ticks show; tick_formatter: reshapes each label; tick_margin: pads it.; with_y_axis keywords: tick_count:, tick_formatter:, tick_margin: ONLY), grid (with_grid keywords: vertical:, horizontal: ONLY), legend, tooltip.
- PART `chart-svg` - The chart canvas (<svg>) - server-computed geometry in a fixed viewBox; role=img, or the focusable role=application accessibilityLayer when the tooltip attaches | states: data-animate (present when animate (the default) - the motion stylesheet and controller key the entrance off it); data-motion=entrance|morph|settled (runtime - the motion rig stamps the animation lifecycle (entrance/morph, then settled)) | vars: --poetry-motion-duration (the entrance/morph duration (animation_duration, ms)); --poetry-motion-easing (the animation easing keyword (animation_easing)); --poetry-motion-delay (the pre-animation hold (animation_begin, ms))
- PART `chart-motion-reveal` - The entrance clipPath rect (the ported area reveal) - the motion stylesheet scales it 0 -> 1; only when animate
- PART `chart-grid` - The gridline group (with_grid) - horizontal and/or vertical rules across the plot
- PART `chart-cursor` - The hover cursor, hidden until the tooltip controller positions and reveals it at the active index - a vertical rule or a translucent band rect (bar charts)
- PART `chart-areas` - The area-mark group - a fill path plus top-curve stroke per series, clipped by the reveal rect while animating
- PART `chart-area` - One series' fill path (var(--color-<key>) or its gradient) | states: data-key (the series key)
- PART `chart-area-stroke` - One series' top-curve stroke path (the source strokes the curve, never the area outline) | states: data-key (the series key)
- PART `chart-bar-series` - One series' bar group | states: data-key (the series key)
- PART `chart-bar` - One bar cell (a per-corner rounded-rect path) | states: data-key (the series key); data-index (the datum index); data-active (runtime - the tooltip controller marks the hovered index); data-motion-origin=bottom|top (when animate - the zero edge the entrance grows from)
- PART `chart-lines` - The line-mark group - each series' curve plus its companion marks
- PART `chart-line` - One series' stroked curve - pathLength=1 when animating so the dash draw-in needs no measurement | states: data-key (the series key)
- PART `chart-dots` - One series' point-dot group (dots: true) | states: data-key (the series key)
- PART `chart-dot` - One point dot (<circle>)
- PART `chart-active-dots` - The hover-marker group (with_tooltip) - pre-rendered hidden circles for every series x index
- PART `chart-active-dot` - One hover marker - display=none until the tooltip controller reveals the active index's dot | states: data-key (the series key); data-index (the datum index); data-active (runtime - rides the marker while its index is the active one)
- PART `chart-x-axis` - The x-axis tick-label group (with_x_axis)
- PART `chart-coordinates` - The embedded per-index geometry payload (<script type=application/json>) the tooltip controller reads - zero chart math in the browser
- WIRING frame: `poetry--charts--tooltip` (if tooltip?) registers; values sync (if) | `poetry--charts--motion` (if animate?) registers
- WIRING svg: `poetry--charts--tooltip` (if tooltip?) actions move on pointermove, leave on pointerleave, focus on focus, blur on blur, keydown on keydown; targets svg
- WIRING coordinates: `poetry--charts--tooltip` (if tooltip?) targets data
- WIRING tooltip_layer: `poetry--charts--tooltip` (if tooltip?) targets tooltip
- RULE: Mix marks freely: with_area / with_bar / with_line - declaration order is paint order.
- RULE: All marks share the x band and ONE y domain; lines and areas ride the band centers.
- RULE: stack: ids only combine within the same mark type (a bar stack never joins an area stack).
- RULE: Colors come from the config - never set fill/stroke on a mark directly.
- RULE: Entrance animation is on by default; each mark keeps its own reveal mechanism.

## container (`poetry_container`)

Class: Poetry::Charts::Container::Component - BEM block `poetry-charts-container`.
- `config:` () - required - The series config - key => { label:, color: } - driving the per-series color emission.
- `id:` (string) - Explicit DOM id token, stable across renders; otherwise the frame gets a unique per-render id.
- PART `chart` - The chart frame (<div>) - the aspect-video chrome, the tooltip layer's positioning anchor, and the id scope the per-series colors are emitted for | states: data-chart (always - the chart instance id (explicit id: or unique per render); the scoped color emission keys off it) | vars: --color-* (per-series color, one entry per series key - the frame's <style> block emits them for [data-chart=<id>] in both themes)
- RULE: Every chart lives inside poetry_container(config:) - the config maps series keys to labels/colors.
- RULE: Reference series colors as var(--color-<key>); never hard-code a color in chart markup.
- RULE: Config colors point at theme tokens (var(--chart-1..5)) or use theme: { light:, dark: } maps.
- RULE: Give charts an explicit id: when the page renders more than one of the same chart.

## legend_content (`poetry_legend_content`)

Class: Poetry::Charts::LegendContent::Component - BEM block `poetry-charts-legend_content`.
- `align:` (symbol) - one of top|bottom, default "bottom", required - Which chart edge the legend sits on: :top pads below it, :bottom (the default) pads above. A style axis, not an option - options silently drop the dictionary's variant classes.
- `config:` () - required - The series config - key => { label:, color: } - the default item source.
- `hide_icon:` (boolean) - default false - Hides the color swatches, leaving labels only.
- `items:` () - Explicit entries ([{ key:, name:, color: }]) overriding the config-derived list.
- `toggle:` (boolean) - default false - Interactive legend: items render as buttons that toggle their series through the live controller (the host chart guards that live: is on).
- PART `chart-legend-content` - The legend row (<div>) - centered swatch + label pairs
- PART `chart-legend-item` - One legend entry (<div>; a <button> in toggle mode) | states: data-key (in toggle mode - the series key the button toggles); data-hidden (in toggle mode - the item's series is toggled off (the live controller stamps it at runtime; the item dims))
- PART `chart-legend-swatch` - The color swatch (<div>) - inline background-color carries the entry's color; omitted with hide_icon or colorless entries
- RULE: The legend derives from the chart config by default - omit items: unless slices differ from series.
- RULE: align: :top pads below (pb-3), :bottom (default) pads above (pt-3) - matching the chart edge it sits on.

## line_chart (`poetry_line_chart`)

A line chart for trends over a continuous axis.

Class: Poetry::Charts::LineChart::Component - BEM block `poetry-charts-line_chart`.
- `animate:` (boolean) - default true - Entrance animation switch - reduced-motion users always get the finished chart regardless.
- `animation_begin:` (integer) - default 0 - Pre-animation hold in milliseconds.
- `animation_duration:` (integer) - default 1500 - Entrance/morph duration in milliseconds.
- `animation_easing:` (symbol) - default "ease" - Animation easing keyword (see EASINGS).
- `config:` () - required - The series config - key => { label:, color: } - naming and coloring every series.
- `data:` () - required - The rows to plot: an array of hashes, one per x category.
- `height:` (integer) - default 360 - ViewBox height in pixels.
- `id:` (string) - Explicit DOM id token, stable across renders; otherwise the chart gets a unique per-render id.
- `label:` (string) - Accessible name for the chart SVG; defaults to one built from the configured series.
- `live:` (boolean) - default false - Embeds the {spec, frame} payload so the client renderer can recompute geometry when data changes without a server round-trip.
- `margin:` () - Plot margin overrides ({ top:, right:, bottom:, left: }), merged over the defaults.
- `sync:` (string)
- `width:` (integer) - default 640 - ViewBox width in pixels; the rendered chart scales to its container.
- `zoom:` (boolean) - default false - Drag-to-zoom on the plot; slices the data client-side, so it needs live: true.
Slots: reference_lines (many; with_reference_line keywords: x:, y:, label:, stroke_dasharray: ONLY), reference_areas (many; with_reference_area keywords: x1:, x2:, y1:, y2:, label:, fill_opacity: ONLY), reference_dots (many; with_reference_dot keywords: x:, y:, r:, label: ONLY), brush (The brush strip below the x axis - drag its window to slice the visible range; needs live: true.; with_brush keywords: height: ONLY), lines (A line series bound to data_key:. dots: marks each point; dot_color_key: reads per-point dot colors from the row; labels: stamps each value above its point; error_key: adds error whiskers.; many; with_line keywords: data_key:, curve:, stroke_width:, dots:, dot_radius:, dot_color_key:, labels:, error_key:, error_width: ONLY), x_axis (with_x_axis keywords: data_key:, tick_formatter:, tick_margin: ONLY), y_axis (The value axis: tick_count: sets how many ticks show; tick_formatter: reshapes each label; tick_margin: pads it.; with_y_axis keywords: tick_count:, tick_formatter:, tick_margin: ONLY), grid (with_grid keywords: vertical:, horizontal: ONLY), legend, tooltip.
- PART `chart-brush` - The brush strip group (with_brush): track + window + two handles below the x axis
- PART `chart-brush-track` - The full-width brush rail
- PART `chart-brush-window` - The selected-range rect the drag moves
- PART `chart-brush-handle` - One draggable window edge | states: data-edge=start|end (always - which edge)
- PART `chart-zoom-selection` - The zoom drag-selection overlay (zoom: true), hidden until a drag starts
- PART `chart-live-payload` - The embedded {spec, frame} JSON the live renderer recomputes geometry from
- PART `chart-svg` - The chart canvas (<svg>) - server-computed geometry in a fixed viewBox; role=img, or the focusable role=application accessibilityLayer when the tooltip attaches | states: data-animate (present when animate (the default) - the motion stylesheet and controller key the entrance off it); data-motion=entrance|morph|settled (runtime - the motion rig stamps the animation lifecycle (entrance/morph, then settled)) | vars: --poetry-motion-duration (the entrance/morph duration (animation_duration, ms)); --poetry-motion-easing (the animation easing keyword (animation_easing)); --poetry-motion-delay (the pre-animation hold (animation_begin, ms))
- PART `chart-grid` - The gridline group (with_grid) - horizontal and/or vertical rules across the plot
- PART `chart-cursor` - The hover cursor, hidden until the tooltip controller positions and reveals it at the active index - a vertical rule or a translucent band rect (bar charts)
- PART `chart-lines` - The line-mark group - each series' curve plus its companion marks
- PART `chart-line` - One series' stroked curve - pathLength=1 when animating so the dash draw-in needs no measurement | states: data-key (the series key)
- PART `chart-dots` - One series' point-dot group (dots: true) | states: data-key (the series key)
- PART `chart-dot` - One point dot (<circle>)
- PART `chart-error-bars` - One series' error-whisker group (error_key:) - cap-stem-cap paths in the foreground color | states: data-key (the series key)
- PART `chart-labels` - One series' value-label group (labels: true) | states: data-key (the series key)
- PART `chart-reference` - The reference-mark group (with_reference_line/_area/_dot), painted above the series
- PART `chart-active-dots` - The hover-marker group (with_tooltip) - pre-rendered hidden circles for every series x index
- PART `chart-active-dot` - One hover marker - display=none until the tooltip controller reveals the active index's dot | states: data-key (the series key); data-index (the datum index); data-active (runtime - rides the marker while its index is the active one)
- PART `chart-x-axis` - The x-axis tick-label group (with_x_axis)
- PART `chart-coordinates` - The embedded per-index geometry payload (<script type=application/json>) the tooltip controller reads - zero chart math in the browser
- WIRING frame: `poetry--charts--tooltip` (if tooltip?) registers; values sync (if) | `poetry--charts--motion` (if animate?) registers | `poetry--charts--live` (if live?) registers; actions receive on poetry-chart:update | `poetry--charts--tooltip` (if) actions refresh on poetry--charts--live:updated | `poetry--charts--window` (if window_features?) registers; values zoom, plot, brush (if)
- WIRING svg: `poetry--charts--tooltip` (if tooltip?) actions move on pointermove, leave on pointerleave, focus on focus, blur on blur, keydown on keydown; targets svg | `poetry--charts--window` (if zoom?) actions startZoom on pointerdown, reset on dblclick
- WIRING coordinates: `poetry--charts--tooltip` (if tooltip?) targets data
- WIRING tooltip_layer: `poetry--charts--tooltip` (if tooltip?) targets tooltip
- WIRING live_payload: `poetry--charts--live` targets payload
- WIRING brush: `poetry--charts--window` (if) actions startBrush on pointerdown
- RULE: Compose from slots: with_grid / with_x_axis(data_key:) / with_line(data_key:) / with_legend.
- RULE: Lines default to stroke-width 2 and NO dots (the ported block look); dots: true adds them.
- RULE: dot_color_key: reads a per-row data key for per-point dot colors (the dots-colors block).
- RULE: labels: true stamps each value above its point; give the chart margin top when using it.
- RULE: Colors come from the config - never set stroke on a line directly.
- RULE: Entrance animation is on by default (source parity); animate: false for a static chart. Reduced-motion users always get the finished chart.

## pie_chart (`poetry_pie_chart`)

A pie chart for showing parts of a whole.

Class: Poetry::Charts::PieChart::Component - BEM block `poetry-charts-pie_chart`.
- `animate:` (boolean) - default true - Entrance animation switch - reduced-motion users always get the finished chart regardless.
- `animation_begin:` (integer) - default 400 - Pre-animation hold in milliseconds.
- `animation_duration:` (integer) - default 1500 - Entrance/morph duration in milliseconds.
- `animation_easing:` (symbol) - default "ease" - Animation easing keyword (see EASINGS).
- `config:` () - required - The series config - name => { label:, color: } - naming and coloring the slices.
- `data:` () - Default rows for pies that don't bring their own data: - one hash per slice.
- `height:` (integer) - default 250 - ViewBox height in pixels.
- `id:` (string) - Explicit DOM id token, stable across renders; otherwise the chart gets a unique per-render id.
- `label:` (string) - Accessible name for the chart SVG; defaults to one built from the configured series.
- `margin:` () - Margin overrides ({ top:, right:, bottom:, left: }), merged over the slim polar default.
- `sync:` (string)
- `width:` (integer) - default 250 - ViewBox width in pixels; the rendered chart scales to its container.
Slots: pies (One ring of slices reading data_key: values and name_key: slice names. inner_radius: makes the donut; padding_angle: spaces the slices; active_index: pops one out by active_grow: pixels.; many; with_pie keywords: data_key:, data:, name_key:, inner_radius:, outer_radius:, padding_angle:, stroke_width:, color_key:, labels:, label_key:, active_index:, active_grow: ONLY), center_label (The donut-hole text: a title line plus an optional subtitle.; with_center_label keywords: title:, subtitle: ONLY), legend (The legend row: align:, items:, and hide_icon:.), tooltip (The hover tooltip; the slice name carries the label, so hide_label defaults on.).
- PART `chart-svg` - The chart canvas (<svg>) - the aria-label surface, the tooltip's focus/keyboard surface (role=application when it attaches), and the motion rig's mount | states: data-animate (when animate (the default) - the entrance tier's flag the motion stylesheet and controller key off); data-motion=entrance|morph|settled (runtime, when animate - the motion engine's lifecycle stamp) | vars: --poetry-motion-delay (the motion rig's entrance delay (animation_begin)); --poetry-motion-duration (the motion rig's entrance duration (animation_duration)); --poetry-motion-easing (the motion rig's easing keyword (animation_easing))
- PART `chart-pie` - One pie's slice group (<g>) - a ring per with_pie slot | states: data-key (always - the series key)
- PART `chart-pie-sector` - One slice (<path>) - fill from its row's color, popped out when active | states: data-key (always - the series key); data-index (on the first pie's slices - the datum index the tooltip walks); data-active (the active slice - server-rendered via active_index:, and reflected onto the hovered/arrow-keyed index by the tooltip controller at runtime); data-motion-group (when animate - the motion rig's sweep group (one per ring)); data-motion-sector (when animate - the motion rig's server-computed sector params for the fan-out sweep)
- PART `chart-labels` - A series' value labels (<g> of <text>, aria-hidden), rendered when the series opts into labels | states: data-key (always - the series key)
- PART `chart-center-label` - The center text (<text>) - title tspan plus optional subtitle filling the chart's middle
- PART `chart-coordinates` - The embedded JSON payload (<script>) the tooltip controller reads - per-category anchors and pre-formatted values, zero chart math in the browser
- WIRING frame: `poetry--charts--tooltip` (if tooltip?) registers; values sync (if) | `poetry--charts--motion` (if animate?) registers
- WIRING svg: `poetry--charts--tooltip` (if tooltip?) actions move on pointermove, leave on pointerleave, focus on focus, blur on blur, keydown on keydown; targets svg | `poetry--charts--tooltip` (if tooltip?) actions enter on pointerover
- WIRING coordinates: `poetry--charts--tooltip` (if tooltip?) targets data
- WIRING tooltip_layer: `poetry--charts--tooltip` (if tooltip?) targets tooltip
- RULE: Rows carry their slice color in a fill key (var(--color-<name>)); the config maps names to labels.
- RULE: inner_radius: 60 makes the donut; with_center_label(title:, subtitle:) fills the hole.
- RULE: Stacked pies: two with_pie slots with their own data: and non-overlapping radii.
- RULE: active_index: pops one slice out by 10px (the donut-active look).
- RULE: The tooltip walks slices by hover AND arrow keys (role=application when attached).
- RULE: Entrance animation is on by default (source parity); animate: false for a static chart. Reduced-motion users always get the finished chart.

## radar_chart (`poetry_radar_chart`)

A radar chart for comparing several variables on radial axes.

Class: Poetry::Charts::RadarChart::Component - BEM block `poetry-charts-radar_chart`.
- `animate:` (boolean) - default true - Entrance animation switch - reduced-motion users always get the finished chart regardless.
- `animation_begin:` (integer) - default 0 - Pre-animation hold in milliseconds.
- `animation_duration:` (integer) - default 1500 - Entrance/morph duration in milliseconds.
- `animation_easing:` (symbol) - default "ease" - Animation easing keyword (see EASINGS).
- `config:` () - required - The series config - key => { label:, color: } - naming and coloring every series.
- `data:` () - required - The rows to plot: an array of hashes, one per category.
- `height:` (integer) - default 250 - ViewBox height in pixels.
- `id:` (string) - Explicit DOM id token, stable across renders; otherwise the chart gets a unique per-render id.
- `label:` (string) - Accessible name for the chart SVG; defaults to one built from the configured series.
- `margin:` () - Margin overrides ({ top:, right:, bottom:, left: }), merged over the slim polar default.
- `outer_radius:` () - default "80%" - The rim radius: a percent string of the max radius, or pixels.
- `sync:` (string)
- `width:` (integer) - default 250 - ViewBox width in pixels; the rendered chart scales to its container.
Slots: radars (A radar series bound to data_key:. fill_opacity: 0 with stroke_width: 2 draws lines only; dots: marks every vertex.; many; with_radar keywords: data_key:, fill_opacity:, stroke_width:, dots:, dot_radius: ONLY), angle_axis (The category labels around the rim: data_key: names the field; tick_formatter: reshapes each label.; with_angle_axis keywords: data_key:, tick_formatter: ONLY), grid (The polar grid: type: :circle swaps polygons for circles; radial_lines: false drops the spokes; fill: tints every ring with a series color at opacity:.; with_grid keywords: type:, radial_lines:, fill:, opacity: ONLY), legend (The legend row: align:, items:, and hide_icon:.), tooltip (The hover tooltip - multi-series rows under the category label.).
- PART `chart-svg` - The chart canvas (<svg>) - the aria-label surface, the tooltip's focus/keyboard surface (role=application when it attaches), and the motion rig's mount | states: data-animate (when animate (the default) - the entrance tier's flag the motion stylesheet and controller key off); data-motion=entrance|morph|settled (runtime, when animate - the motion engine's lifecycle stamp) | vars: --poetry-motion-delay (the motion rig's entrance delay (animation_begin)); --poetry-motion-duration (the motion rig's entrance duration (animation_duration)); --poetry-motion-easing (the motion rig's easing keyword (animation_easing)); --poetry-motion-center (the polar center the CSS entrance scales the series from)
- PART `chart-polar-grid` - The polar grid (<g>, aria-hidden) - ring and spoke linework behind the series
- PART `chart-radars` - The series layer (<g>) - every radar polygon renders here; the CSS entrance scales this group from the polar center
- PART `chart-radar` - One series' closed polygon (<path>) - config color, 0.6 fill by default | states: data-key (always - the series key)
- PART `chart-dots` - A series' vertex dots (<g>), rendered when dots: true | states: data-key (always - the series key)
- PART `chart-dot` - One vertex dot (<circle>) - solid, at the series color
- PART `chart-angle-axis` - The category labels around the rim (<g> of <text>)
- PART `chart-hit-wedges` - The tooltip's hit layer (<g>), rendered when the tooltip attaches
- PART `chart-hit-wedge` - One per-category hit wedge (<path>, transparent but painted so it hit-tests) - the tooltip's hover target | states: data-index (always - the datum index); data-active (the hovered/arrow-keyed category - the tooltip controller reflects the active index here at runtime)
- PART `chart-coordinates` - The embedded JSON payload (<script>) the tooltip controller reads - per-category anchors and pre-formatted values, zero chart math in the browser
- WIRING frame: `poetry--charts--tooltip` (if tooltip?) registers; values sync (if) | `poetry--charts--motion` (if animate?) registers
- WIRING svg: `poetry--charts--tooltip` (if tooltip?) actions move on pointermove, leave on pointerleave, focus on focus, blur on blur, keydown on keydown; targets svg | `poetry--charts--tooltip` (if tooltip?) actions enter on pointerover
- WIRING coordinates: `poetry--charts--tooltip` (if tooltip?) targets data
- WIRING tooltip_layer: `poetry--charts--tooltip` (if tooltip?) targets tooltip
- RULE: Compose from slots: with_angle_axis(data_key:) / with_grid / with_radar(data_key:) / with_legend.
- RULE: Radars fill at 0.6 opacity by default; lines-only = fill_opacity: 0, stroke_width: 2.
- RULE: with_grid type: :circle swaps polygons for circles; fill: :desktop tints every grid ring (opacity 0.2, compounding toward the center - the grid-fill look).
- RULE: dots: true marks every vertex (r 4, solid).
- RULE: Colors come from the config - never set fill/stroke on a radar directly.
- RULE: Entrance animation is on by default (source parity); animate: false for a static chart. Reduced-motion users always get the finished chart.

## radial_bar_chart (`poetry_radial_bar_chart`)

A radial bar chart with bars wrapped around a circular axis.

Class: Poetry::Charts::RadialBarChart::Component - BEM block `poetry-charts-radial_bar_chart`.
- `animate:` (boolean) - default true - Entrance animation switch - reduced-motion users always get the finished chart regardless.
- `animation_begin:` (integer) - default 0 - Pre-animation hold in milliseconds.
- `animation_duration:` (integer) - default 1500 - Entrance/morph duration in milliseconds.
- `animation_easing:` (symbol) - default "ease" - Animation easing keyword (see EASINGS).
- `config:` () - required - The series config - name => { label:, color: } - naming and coloring the rings.
- `data:` () - required - The rows to plot: an array of hashes, one ring per row.
- `end_angle:` (integer) - default 360 - Where the sweep ends - 180 makes a half gauge.
- `height:` (integer) - default 250 - ViewBox height in pixels.
- `id:` (string) - Explicit DOM id token, stable across renders; otherwise the chart gets a unique per-render id.
- `inner_radius:` () - default "20%" - The innermost ring edge: a percent string of the max radius, or pixels.
- `label:` (string) - Accessible name for the chart SVG; defaults to one built from the configured series.
- `margin:` () - Margin overrides ({ top:, right:, bottom:, left: }), merged over the slim polar default.
- `max_value:` () - The angle-axis maximum: nil = the largest single value, so the largest ring closes the full sweep EXACTLY (nicing it would leave a notch); stacked gauges pass the stack total when the segments should fill the span.
- `name_key:` (string) - default "name" - The row key naming each ring.
- `outer_radius:` () - default "80%" - The outermost ring edge: a percent string of the max radius, or pixels.
- `start_angle:` (integer) - default 0 - Where the sweep starts, in degrees.
- `sync:` (string)
- `width:` (integer) - default 250 - ViewBox width in pixels; the rendered chart scales to its container.
Slots: radial_bars (A radial series reading data_key: values. background: draws the muted track ring; bars sharing a stack: id share the ring and stack by angle; corner_radius: rounds the arc ends.; many; with_radial_bar keywords: data_key:, stack:, background:, corner_radius:, color_key:, labels:, label_key: ONLY), polar_grid (The disc track behind the rings: radii: places the circles (default: each ring's centerline), fills: tints them, and radial_lines: draws the faint value spokes that show through ring gaps and the open wedge (on by default; gauges turn them off).; with_polar_grid keywords: radii:, fills:, radial_lines: ONLY), center_label (The center text: a title line plus an optional subtitle. The default is the full gauge's big centered number; compact: shrinks it and sits it just above a half gauge's flat baseline.; with_center_label keywords: title:, subtitle:, compact: ONLY), legend (The legend row: align:, items:, and hide_icon:.), tooltip (The hover tooltip; the ring name carries the label, so hide_label defaults on.).
- PART `chart-svg` - The chart canvas (<svg>) - the aria-label surface, the tooltip's focus/keyboard surface (role=application when it attaches), and the motion rig's mount | states: data-animate (when animate (the default) - the entrance tier's flag the motion stylesheet and controller key off); data-motion=entrance|morph|settled (runtime, when animate - the motion engine's lifecycle stamp) | vars: --poetry-motion-delay (the motion rig's entrance delay (animation_begin)); --poetry-motion-duration (the motion rig's entrance duration (animation_duration)); --poetry-motion-easing (the motion rig's easing keyword (animation_easing))
- PART `chart-polar-grid` - The polar grid (<g>, aria-hidden) - ring and spoke linework behind the series
- PART `chart-radial-series` - One series' ring group (<g>) | states: data-key (always - the series key)
- PART `chart-radial-background` - The muted track ring (<path>) behind a bar, rendered when background: true
- PART `chart-radial-bar` - One angular bar (<path>) - a ring per data row, sweep proportional to value | states: data-key (always - the series key); data-index (on the first series' bars - the datum index the tooltip walks); data-active (the hovered/arrow-keyed bar - the tooltip controller reflects the active index here at runtime); data-motion-group (when animate - the motion rig's sweep group (one per ring)); data-motion-sector (when animate - the motion rig's server-computed sector params for the fan-out sweep)
- PART `chart-labels` - A series' value labels (<g> of <text>, aria-hidden), rendered when the series opts into labels | states: data-key (always - the series key)
- PART `chart-center-label` - The center text (<text>) - title tspan plus optional subtitle filling the chart's middle
- PART `chart-coordinates` - The embedded JSON payload (<script>) the tooltip controller reads - per-category anchors and pre-formatted values, zero chart math in the browser
- WIRING frame: `poetry--charts--tooltip` (if tooltip?) registers; values sync (if) | `poetry--charts--motion` (if animate?) registers
- WIRING svg: `poetry--charts--tooltip` (if tooltip?) actions move on pointermove, leave on pointerleave, focus on focus, blur on blur, keydown on keydown; targets svg | `poetry--charts--tooltip` (if tooltip?) actions enter on pointerover
- WIRING coordinates: `poetry--charts--tooltip` (if tooltip?) targets data
- WIRING tooltip_layer: `poetry--charts--tooltip` (if tooltip?) targets tooltip
- RULE: One ring per data row; rows carry their color in a fill key (var(--color-<name>)).
- RULE: background: true draws the muted track ring behind each bar (the gauge look).
- RULE: Stack two radial bars with the same stack: id - they share the ring and stack by ANGLE.
- RULE: corner_radius rounds the arc ends (10 on a 10px ring = full pill caps).
- RULE: with_polar_grid(radii:, fills:) draws the shape/text blocks' disc track; with_center_label fills the middle.
- RULE: Entrance animation is on by default (source parity); animate: false for a static chart. Reduced-motion users always get the finished chart.

## scatter_chart (`poetry_scatter_chart`)

A scatter chart for the relationship between two variables.

Class: Poetry::Charts::ScatterChart::Component - BEM block `poetry-charts-scatter_chart`.
- `animate:` (boolean) - default true - Entrance animation switch - reduced-motion users always get the finished chart regardless.
- `animation_begin:` (integer) - default 0 - Pre-animation hold in milliseconds.
- `animation_duration:` (integer) - default 400 - Entrance/morph duration in milliseconds.
- `animation_easing:` (symbol) - default "linear" - Animation easing keyword (see EASINGS).
- `config:` () - required - The series config - key => { label:, color: } - naming and coloring every series.
- `data:` () - Default rows for series that don't bring their own data: - one hash per point.
- `height:` (integer) - default 360 - ViewBox height in pixels.
- `id:` (string) - Explicit DOM id token, stable across renders; otherwise the chart gets a unique per-render id.
- `label:` (string) - Accessible name for the chart SVG; defaults to one built from the configured series.
- `margin:` () - Plot margin overrides ({ top:, right:, bottom:, left: }), merged over the defaults.
- `sync:` (string)
- `width:` (integer) - default 640 - ViewBox width in pixels; the rendered chart scales to its container.
Slots: reference_lines (many; with_reference_line keywords: x:, y:, label:, stroke_dasharray: ONLY), reference_areas (many; with_reference_area keywords: x1:, x2:, y1:, y2:, label:, fill_opacity: ONLY), reference_dots (many; with_reference_dot keywords: x:, y:, r:, label: ONLY), scatters (A point series colored by key:. data: gives it its own rows; error_key: adds error whiskers.; many; with_scatter keywords: key:, data:, error_key:, error_width: ONLY), x_axis (The numeric x axis: data_key: names the row key to plot; name: labels its tooltip row.; with_x_axis keywords: data_key:, tick_count:, tick_margin:, name: ONLY), y_axis (The numeric y axis: data_key: names the row key to plot; name: labels its tooltip row.; with_y_axis keywords: data_key:, tick_count:, tick_margin:, name: ONLY), z_axis (A third dimension sizing the markers: range: is marker AREA in px2 mapped linearly from the data_key: values.; with_z_axis keywords: data_key:, range: ONLY), grid (The gridlines: both directions by default.; with_grid keywords: vertical:, horizontal: ONLY), legend (The legend row: align:, items:, and hide_icon:.), tooltip (The hover tooltip - per-point x/y(/z) rows under the series name.).
- PART `chart-svg` - The chart canvas (<svg>) - server-computed geometry in a fixed viewBox; role=img, or the focusable role=application accessibilityLayer when the tooltip attaches | states: data-animate (present when animate (the default) - the motion stylesheet and controller key the entrance off it); data-motion=entrance|morph|settled (runtime - the motion rig stamps the animation lifecycle (entrance/morph, then settled)) | vars: --poetry-motion-duration (the entrance/morph duration (animation_duration, ms)); --poetry-motion-easing (the animation easing keyword (animation_easing)); --poetry-motion-delay (the pre-animation hold (animation_begin, ms))
- PART `chart-grid` - The gridline group (with_grid) - horizontal and/or vertical rules across the plot
- PART `chart-scatters` - The scatter-mark group - every series' points flattened with a global index
- PART `chart-scatter-point` - One data point (<circle>) - r carries the z-axis area sizing | states: data-key (the series key); data-index (the point's global index across every series); data-active (runtime - the tooltip controller marks the hovered point)
- PART `chart-error-bars` - One series' error-whisker group (error_key:) - cap-stem-cap paths in the foreground color | states: data-key (the series key)
- PART `chart-reference` - The reference-mark group (with_reference_line/_area/_dot), painted above the series
- PART `chart-x-axis` - The x-axis tick-label group (with_x_axis)
- PART `chart-y-axis` - The y-axis tick-label group (with_y_axis)
- PART `chart-coordinates` - The embedded per-index geometry payload (<script type=application/json>) the tooltip controller reads - zero chart math in the browser
- WIRING frame: `poetry--charts--tooltip` (if tooltip?) registers; values sync (if) | `poetry--charts--motion` (if animate?) registers
- WIRING svg: `poetry--charts--tooltip` (if tooltip?) actions move on pointermove, leave on pointerleave, focus on focus, blur on blur, keydown on keydown; targets svg | `poetry--charts--tooltip` (if tooltip?) actions enter on pointerover
- WIRING coordinates: `poetry--charts--tooltip` (if tooltip?) targets data
- WIRING tooltip_layer: `poetry--charts--tooltip` (if tooltip?) targets tooltip
- RULE: Both axes are numeric: with_x_axis(data_key:) / with_y_axis(data_key:) name the row keys to plot.
- RULE: with_scatter(key:) colors points var(--color-<key>); data: gives a series its own rows.
- RULE: with_z_axis(data_key:, range: [64, 144]) sizes points by a third dimension - the range is marker AREA in px2 (the source's z-axis contract).
- RULE: The tooltip hits per point and shows the x/y(/z) values with the series color.
- RULE: Entrance animation is on by default (400ms linear, source-exact); animate: false for a static chart.

## tooltip_content (`poetry_tooltip_content`)

Class: Poetry::Charts::TooltipContent::Component - BEM block `poetry-charts-tooltip_content`.
- `config:` () - required - The series config - key => { label:, color: } - resolving row names and colors.
- `hide_indicator:` (boolean) - default false - Hides the row swatches.
- `hide_label:` (boolean) - default false - Hides the category label.
- `indicator:` (symbol) - one of dot|line|dashed, default "dot" - The row swatch shape.
- `items:` () - required - The rows: [{ key:, name:, value:, color: }] hashes, one per series.
- `label:` (string) - The category label above the rows, resolved through the config.
- PART `chart-tooltip-content` - The tooltip box (<div>) - the styled chrome the chart's tooltip controller positions and text-swaps
- PART `chart-tooltip-label` - The category label (<div>) - above the rows, or nested inside the single row for line/dashed indicators
- PART `chart-tooltip-item` - One series row (<div>) - indicator + name + value | states: data-key (always - the series key the controller matches values by)
- PART `chart-tooltip-indicator` - The row's swatch (<div>) - dot/line/dashed per indicator:, hidden with hide_indicator | vars: --color-bg (the swatch fill - carries the row's series color (inline; polar charts retint it to the hovered slice's color at runtime)); --color-border (the swatch border - the same series color as the fill)
- PART `chart-tooltip-name` - The series name (<span>) - resolved through the chart config
- PART `chart-tooltip-value` - The formatted value (<span>) - the mono tabular column, numbers delimited
- RULE: Tooltip rows resolve names/colors through the chart config - pass key:, not a display string.
- RULE: indicator: :dot (default) | :line | :dashed matches the ported variants.
- RULE: Numeric values render delimited (1,234) in the mono tabular column automatically.

## tooltip_layer (`poetry_tooltip_layer`)

Class: Poetry::Charts::TooltipLayer::Component - BEM block `poetry-charts-tooltip_layer`.
- `config:` () - required - The series config - key => { label:, color: } - resolving row names and colors.
- `hide_indicator:` (boolean) - default false - Hides the row swatches.
- `hide_label:` (boolean) - default false - Hides the category label.
- `indicator:` (symbol) - default "dot" - The row swatch shape.
- `series_keys:` () - required - The series keys to pre-render rows for.
- WIRING root: `poetry--charts--tooltip` targets tooltip

