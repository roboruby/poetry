import {
  scaleLinear, scaleBand, scalePoint,
  line as d3Line, area as d3Area, stack as d3Stack,
  stackOffsetNone, stackOffsetExpand,
  curveLinear, curveNatural, curveStep, curveStepBefore, curveStepAfter, curveMonotoneX,
  getNiceTickValues,
} from "@poetry/charts/d3"

// The live cartesian renderer (Phase B-W2): {spec, frame} + data ->
// geometry via the vendored kernel, applied to the server-rendered SVG as
// IN-PLACE attribute updates - never innerHTML - so the tooltip's targets,
// focus state, and host listeners survive every tick.
//
// This is lib/poetry/charts/cartesian.rb (+ the bar component's slot and
// path math) transcribed conventions-and-formatting exact: the kernel IS
// the d3 that generated the Ruby port's oracle fixtures, nice ticks are
// recharts' own getNiceTickValues, fnum mirrors Ruby's 2-decimal
// half-away-from-zero rounding with native JS stringification, and paths
// come from d3-shape's default 3-digit output - so a kernel render of
// dataset X is byte-equal to the server rendering dataset X (proven by
// the live_fixtures parity suite).
//
// Scope (declared): the streaming trio (area / line / bar), dense data,
// no labels, no tick formatters (the Ruby side raises on both at render).
// Count changes (sliding-window warm-up) reconcile group children by
// cloning the last sibling - still attribute-channel: engine-owned
// subtrees outside the group are never touched.

const X_AXIS_HEIGHT = 30
const Y_AXIS_WIDTH = 60

const CURVES = {
  linear: curveLinear,
  natural: curveNatural,
  step: curveStep,
  step_before: curveStepBefore,
  step_after: curveStepAfter,
  monotone_x: curveMonotoneX,
}

// Ruby fnum: 2-decimal rounding (half away from zero - Ruby Float#round),
// JS-native stringification (bare integers).
const fnum = (v) => {
  const scaled = v * 100
  return String((Math.sign(scaled) * Math.round(Math.abs(scaled))) / 100)
}

const round2 = (v) => (Math.sign(v) * Math.round(Math.abs(v) * 100)) / 100

// ActiveSupport number_to_delimited, byte-for-byte for numerics: integer
// part grouped with commas, decimal part verbatim, strings untouched.
export function displayValue(value) {
  if (value == null) return null
  if (typeof value === "number") {
    const [integer, fraction] = String(value).split(".")
    const grouped = integer.replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    return fraction ? `${grouped}.${fraction}` : grouped
  }
  return String(value)
}

// -- the pipeline (Cartesian, transcribed) ------------------------------

export function computeCartesian(payload) {
  const { spec, frame } = payload
  // The window (C-W5 brush/zoom): [start, end] inclusive indices slice
  // the FULL data before anything computes.
  const data = frame.window
    ? spec.data.slice(frame.window[0], frame.window[1] + 1)
    : spec.data
  // Hidden series (the C-W4 legend toggle) leave the domain and the
  // stacks entirely - recharts' rescale-on-hide semantics.
  const hidden = new Set(frame.hidden ?? [])
  const series = spec.series.filter((entry) => !hidden.has(entry.key))
  const horizontal = frame.layout === "horizontal"
  const categoryAxis = frame.categoryAxis
  const margin = frame.margin

  const reservedLeft = (horizontal && categoryAxis) || (!horizontal && frame.valueAxis)
  const plotLeft = margin.left + (reservedLeft ? Y_AXIS_WIDTH : 0)
  const plotRight = frame.width - margin.right
  const plotTop = margin.top
  const plotBottom = frame.height - margin.bottom - (!horizontal && categoryAxis ? X_AXIS_HEIGHT : 0)

  const xKey = horizontal ? spec.axes?.y?.dataKey : spec.axes?.x?.dataKey
  const categories = xKey ? data.map((row) => row[xKey]) : data.map((_, i) => i)

  // Index-domain scales: numerically identical to d3 category domains,
  // immune to duplicate labels (the Ruby ports position by index too).
  const indexes = categories.map((_, i) => i)
  const categoryRange = horizontal ? [plotTop, plotBottom] : [plotLeft, plotRight]
  const band = frame.xScaleType === "band"
  const xScale = (band ? scaleBand() : scalePoint()).domain(indexes).range(categoryRange)
  const bandWidth = band ? xScale.bandwidth() : 0
  const xPositions = indexes.map((i) => xScale(i))
  const xCenters = band ? xPositions.map((x) => x + bandWidth / 2) : xPositions

  const valueAt = (i, key) => {
    const value = data[i]?.[key]
    return value == null ? NaN : Number(value)
  }

  // d3 stacks per stack id: keys in series order within the stack.
  const stackBands = {}
  for (const entry of series) {
    const id = entry.stack
    if (id == null || stackBands[id]) continue
    const keys = series.filter((s) => s.stack === id).map((s) => s.key)
    const offset = frame.offset === "expand" ? stackOffsetExpand : stackOffsetNone
    const stacked = d3Stack().keys(keys).offset(offset)(data)
    stackBands[id] = Object.fromEntries(stacked.map((s) => [s.key, s.map((p) => [p[0], p[1]])]))
  }

  // The raw numeric domain before nicing: recharts' [0, 'auto'].
  const values = []
  for (const entry of series) {
    if (entry.stack != null) {
      for (const [lo, hi] of stackBands[entry.stack][entry.key]) {
        if (!Number.isNaN(lo)) values.push(lo)
        if (!Number.isNaN(hi)) values.push(hi)
      }
    } else {
      for (let i = 0; i < data.length; i++) {
        const value = valueAt(i, entry.key)
        if (!Number.isNaN(value)) values.push(value)
      }
    }
  }
  const rawDomain = values.length ? [Math.min(0, Math.min(...values)), Math.max(...values)] : [0, 1]
  const yTicks = getNiceTickValues(frame.offset === "expand" ? [0, 1] : rawDomain, frame.yTickCount, true)
  const yDomain = [yTicks[0], yTicks[yTicks.length - 1]]
  const yScale = scaleLinear()
    .domain(yDomain)
    .range(horizontal ? [plotLeft, plotRight] : [plotBottom, plotTop])

  const lo = Math.min(yDomain[0], yDomain[1])
  const hi = Math.max(yDomain[0], yDomain[1])
  const baseline = yScale(Math.min(Math.max(0, lo), hi))

  const pointFor = (index, key, basePx, topPx) => {
    const value = valueAt(index, key)
    return horizontal
      ? { y: xCenters[index], x0: basePx, x1: topPx, value }
      : { x: xCenters[index], y0: basePx, y1: topPx, value }
  }

  const points = (entry) => {
    if (entry.stack != null) {
      return stackBands[entry.stack][entry.key].map(([lo1, hi1], i) =>
        pointFor(i, entry.key, yScale(lo1), yScale(hi1))
      )
    }
    return data.map((_, i) => pointFor(i, entry.key, baseline, yScale(valueAt(i, entry.key))))
  }

  return {
    horizontal, hidden, rows: data, plotLeft, plotRight, plotTop, plotBottom,
    categories, xPositions, xCenters, bandWidth,
    yTicks, yScale, baseline, points, valueAt,
  }
}

// -- DOM application ----------------------------------------------------

// Update in place; when a group's child count changes (sliding-window
// warm-up), clone the last sibling as the template.
function reconcile(nodes, count) {
  const list = [...nodes]
  while (list.length > count) list.pop().remove()
  while (list.length < count && list.length > 0) {
    const clone = list[list.length - 1].cloneNode(true)
    list[list.length - 1].after(clone)
    list.push(clone)
  }
  return list
}

function seriesPathAttrs(type, geometry, entry) {
  const pts = geometry.points(entry)
  const defined = (p) => !Number.isNaN(p.value)
  const curve = CURVES[entry.curve ?? "natural"] ?? curveNatural

  if (type === "area") {
    const fill = d3Area().x((p) => p.x).y0((p) => p.y0).y1((p) => p.y1).defined(defined).curve(curve)(pts)
    const stroke = d3Line().x((p) => p.x).y((p) => p.y1).defined(defined).curve(curve)(pts)
    return { fill, stroke }
  }
  const path = d3Line()
    .x((p) => (geometry.horizontal ? p.x1 : p.x))
    .y((p) => (geometry.horizontal ? p.y : p.y1))
    .defined(defined)
    .curve(CURVES[entry.curve ?? "linear"] ?? curveLinear)(pts)
  return { path }
}

// The bar component's combineAllBarPositions port: 10% band trim, 4px
// group gap, size js_round-ed past 1px.
function barSlots(spec, frame, bandWidth) {
  const groups = [...new Set(spec.series.map((s) => s.stack ?? s.key))]
  const trim = percentValue(frame.barCategoryGap, bandWidth)
  let gap = Number(frame.barGap)
  if (bandWidth - 2 * trim - (groups.length - 1) * gap <= 0) gap = 0
  let size = (bandWidth - 2 * trim - (groups.length - 1) * gap) / groups.length
  if (size > 1) size = Math.round(size)
  return Object.fromEntries(groups.map((group, i) => [group, { offset: trim + (size + gap) * i, size }]))
}

function percentValue(value, total) {
  const text = String(value)
  return text.endsWith("%") ? (total * parseFloat(text)) / 100 : parseFloat(text)
}

// bar_path, per-corner radii clamped to half the rect (recharts Rectangle).
function barPath(radius, cell) {
  const radii = Array.isArray(radius) ? radius.map(Number) : Array(4).fill(Number(radius))
  const max = Math.min(cell.width / 2, cell.height / 2)
  const [tl, tr, br, bl] = radii.map((r) => Math.min(Math.max(r, 0), max))
  const f = fnum
  let d = `M${f(cell.x)},${f(cell.y + tl)}`
  if (tl > 0) d += `A${f(tl)},${f(tl)},0,0,1,${f(cell.x + tl)},${f(cell.y)}`
  d += `L${f(cell.x + cell.width - tr)},${f(cell.y)}`
  if (tr > 0) d += `A${f(tr)},${f(tr)},0,0,1,${f(cell.x + cell.width)},${f(cell.y + tr)}`
  d += `L${f(cell.x + cell.width)},${f(cell.y + cell.height - br)}`
  if (br > 0) d += `A${f(br)},${f(br)},0,0,1,${f(cell.x + cell.width - br)},${f(cell.y + cell.height)}`
  d += `L${f(cell.x + bl)},${f(cell.y + cell.height)}`
  if (bl > 0) d += `A${f(bl)},${f(bl)},0,0,1,${f(cell.x)},${f(cell.y + cell.height - bl)}`
  return `${d}Z`
}

function barCells(geometry, entry, slot) {
  const pts = geometry.points(entry)
  const cells = []
  pts.forEach((p, i) => {
    if (Number.isNaN(p.value)) return
    if (geometry.horizontal) {
      const left = Math.min(p.x0, p.x1)
      cells.push({ index: i, value: p.value, x: left, y: geometry.xPositions[i] + slot.offset,
                   width: Math.abs(p.x1 - p.x0), height: slot.size })
    } else {
      const top = Math.min(p.y0, p.y1)
      cells.push({ index: i, value: p.value, x: geometry.xPositions[i] + slot.offset, y: top,
                   width: slot.size, height: Math.abs(p.y1 - p.y0) })
    }
  })
  return cells
}

// Apply a payload (whose spec.data is the CURRENT data) to the frame
// element (the div wrapping svg + chrome + scripts). Returns the geometry
// so callers (the live controller) can chain.
export function applyCartesian(frame, payload) {
  const svg = frame.querySelector('[data-slot="chart-svg"]')
  const geometry = computeCartesian(payload)
  const { spec } = payload
  const type = spec.type

  for (const entry of spec.series) {
    if (geometry.hidden.has(entry.key)) {
      setSeriesVisibility(svg, entry.key, false)
      continue
    }
    setSeriesVisibility(svg, entry.key, true)
    if (type === "area") {
      const { fill, stroke } = seriesPathAttrs(type, geometry, entry)
      svg.querySelector(`path[data-slot="chart-area"][data-key="${entry.key}"]`)?.setAttribute("d", fill)
      svg.querySelector(`path[data-slot="chart-area-stroke"][data-key="${entry.key}"]`)?.setAttribute("d", stroke)
    } else if (type === "line") {
      const { path } = seriesPathAttrs(type, geometry, entry)
      svg.querySelector(`path[data-slot="chart-line"][data-key="${entry.key}"]`)?.setAttribute("d", path)
      applyDots(svg, geometry, entry)
    } else if (type === "bar") {
      applyBars(svg, geometry, payload, entry)
    }
    applyActiveDots(svg, geometry, entry)
  }

  applyGrid(svg, geometry)
  applyAxes(svg, geometry, payload)
  applyCoordinates(frame, geometry, payload)
  return geometry
}

// A hidden series' marks (paths, dot groups, bar groups, active dots)
// toggle display - attribute-channel, the DOM stays intact for the
// toggle back.
function setSeriesVisibility(svg, key, visible) {
  const selector = [
    `path[data-slot="chart-area"][data-key="${key}"]`,
    `path[data-slot="chart-area-stroke"][data-key="${key}"]`,
    `path[data-slot="chart-line"][data-key="${key}"]`,
    `g[data-slot="chart-dots"][data-key="${key}"]`,
    `g[data-slot="chart-bar-series"][data-key="${key}"]`,
    `circle[data-slot="chart-active-dot"][data-key="${key}"]`,
  ].join(", ")
  for (const el of svg.querySelectorAll(selector)) {
    if (visible) el.style.removeProperty("display")
    else el.style.setProperty("display", "none")
  }
}

function applyDots(svg, geometry, entry) {
  const group = svg.querySelector(`g[data-slot="chart-dots"][data-key="${entry.key}"]`)
  if (!group) return
  const markers = geometry.points(entry).filter((p) => !Number.isNaN(p.value))
  const dots = reconcile(group.querySelectorAll('[data-slot="chart-dot"]'), markers.length)
  dots.forEach((dot, i) => {
    dot.setAttribute("cx", fnum(geometry.horizontal ? markers[i].x1 : markers[i].x))
    dot.setAttribute("cy", fnum(geometry.horizontal ? markers[i].y : markers[i].y1))
  })
}

function applyActiveDots(svg, geometry, entry) {
  const dots = svg.querySelectorAll(`circle[data-slot="chart-active-dot"][data-key="${entry.key}"]`)
  if (!dots.length) return
  const markers = geometry.points(entry)
    .map((p, i) => ({ ...p, index: i }))
    .filter((p) => !Number.isNaN(p.value))
  const group = dots[0].parentNode
  const list = reconcile(dots, markers.length)
  list.forEach((dot, i) => {
    dot.setAttribute("data-index", String(markers[i].index))
    dot.setAttribute("cx", fnum(geometry.horizontal ? markers[i].x1 : markers[i].x))
    dot.setAttribute("cy", fnum(geometry.horizontal ? markers[i].y : markers[i].y1))
  })
  group.append(...list) // keep per-key runs contiguous after cloning
}

function applyBars(svg, geometry, payload, entry) {
  const group = svg.querySelector(`g[data-slot="chart-bar-series"][data-key="${entry.key}"]`)
  if (!group) return
  const slots = barSlots(payload.spec, payload.frame, geometry.bandWidth)
  const slot = slots[entry.stack ?? entry.key]
  const radius = payload.frame.series?.[entry.key]?.radius ?? 0
  const cells = barCells(geometry, entry, slot)
  const bars = reconcile(group.querySelectorAll('[data-slot="chart-bar"]'), cells.length)
  bars.forEach((bar, i) => {
    bar.setAttribute("data-index", String(cells[i].index))
    bar.setAttribute("d", barPath(radius, cells[i]))
    if (bar.hasAttribute("data-motion-origin")) {
      const negative = cells[i].value < 0
      bar.setAttribute("data-motion-origin",
        geometry.horizontal ? (negative ? "right" : "left") : (negative ? "top" : "bottom"))
    }
  })
}

function applyGrid(svg, geometry) {
  const grid = svg.querySelector('g[data-slot="chart-grid"]')
  if (!grid) return
  const lines = [...grid.querySelectorAll("line")]
  const horizontalLines = lines.filter((l) => l.getAttribute("y1") === l.getAttribute("y2"))
  const verticalLines = lines.filter((l) => l.getAttribute("y1") !== l.getAttribute("y2"))

  // Vertical layout: horizontal rules ride y ticks, vertical ones ride
  // category centers; the horizontal layout swaps the sources.
  const hSource = geometry.horizontal ? geometry.xCenters : geometry.yTicks.map((t) => geometry.yScale(t))
  const vSource = geometry.horizontal ? geometry.yTicks.map((t) => geometry.yScale(t)) : geometry.xCenters

  if (horizontalLines.length) {
    reconcile(horizontalLines, hSource.length).forEach((el, i) => {
      el.setAttribute("x1", fnum(geometry.plotLeft))
      el.setAttribute("x2", fnum(geometry.plotRight))
      el.setAttribute("y1", fnum(hSource[i]))
      el.setAttribute("y2", fnum(hSource[i]))
    })
  }
  if (verticalLines.length) {
    reconcile(verticalLines, vSource.length).forEach((el, i) => {
      el.setAttribute("x1", fnum(vSource[i]))
      el.setAttribute("x2", fnum(vSource[i]))
      el.setAttribute("y1", fnum(geometry.plotTop))
      el.setAttribute("y2", fnum(geometry.plotBottom))
    })
  }
}

function applyAxes(svg, geometry, payload) {
  const { frame } = payload
  const xAxis = svg.querySelector('g[data-slot="chart-x-axis"]')
  if (xAxis) {
    reconcile(xAxis.querySelectorAll("text"), geometry.categories.length).forEach((text, i) => {
      text.setAttribute("x", fnum(geometry.xCenters[i]))
      text.setAttribute("y", fnum(geometry.plotBottom + (frame.xTickMargin ?? 8)))
      text.textContent = String(geometry.categories[i])
    })
  }

  const yAxis = svg.querySelector('g[data-slot="chart-y-axis"]')
  if (yAxis) {
    if (geometry.horizontal) {
      // The category strip down the left (horizontal bars).
      reconcile(yAxis.querySelectorAll("text"), geometry.categories.length).forEach((text, i) => {
        text.setAttribute("x", fnum(geometry.plotLeft - (frame.yTickMargin ?? 8)))
        text.setAttribute("y", fnum(geometry.xCenters[i]))
        text.textContent = String(geometry.categories[i])
      })
    } else {
      reconcile(yAxis.querySelectorAll("text"), geometry.yTicks.length).forEach((text, i) => {
        text.setAttribute("x", fnum(geometry.plotLeft - (frame.yTickMargin ?? 8)))
        text.setAttribute("y", fnum(geometry.yScale(geometry.yTicks[i])))
        text.textContent = String(geometry.yTicks[i])
      })
    }
  }
}

// Regenerate the tooltip's embedded coordinates (Cartesian#coordinates,
// transcribed) - the DOM always holds current state; the live controller
// dispatches the refresh that re-parses it.
function applyCoordinates(frame, geometry, payload) {
  const script = frame.querySelector('script[data-slot="chart-coordinates"]')
  if (!script) return
  const { spec } = payload
  const topKey = geometry.horizontal ? "x1" : "y1"
  // Hidden series drop off the wire entirely - their tooltip rows hide
  // (a row with no values entry never shows).
  const visible = spec.series.filter((entry) => !geometry.hidden.has(entry.key))
  const coordinates = {
    layout: payload.frame.layout,
    categories: geometry.categories,
    [geometry.horizontal ? "y" : "x"]: geometry.xCenters.map(round2),
    series: Object.fromEntries(visible.map((entry) => [
      entry.key,
      geometry.points(entry).map((p) => (Number.isNaN(p.value) ? null : round2(p[topKey]))),
    ])),
    values: Object.fromEntries(visible.map((entry) => [
      entry.key,
      geometry.rows.map((row) => displayValue(row[entry.key])),
    ])),
  }
  script.textContent = JSON.stringify(coordinates)
}
