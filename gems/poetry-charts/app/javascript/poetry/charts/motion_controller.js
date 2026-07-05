import { Controller } from "@hotwired/stimulus"
import { tween } from "@poetry/charts/motion/tween"
import { sectorPath } from "@poetry/charts/motion/sector"

// The chart motion engine: the JS half of the entrance tier plus
// the cross-render morph. Cartesian + radar entrances are pure CSS (the
// motion stylesheet); this controller adds what CSS cannot do - the polar
// fan-out and the FLIP morph between server renders - and stamps a
// data-motion lifecycle attribute ("entrance" / "morph" -> "settled") on
// the SVG so tests and hosts can observe the engine.
//
// ENTRANCE (A-W2). The fan-out is recharts' Pie stepData accumulator
// (Pie.tsx): every sector's angular width interpolates 0 -> final
// simultaneously, re-accumulated end-to-end each frame from the group's
// first startAngle, with the FINAL-geometry gaps preserved as constant
// padding. Sectors carry their server-computed params in
// data-motion-sector and their sweep group in data-motion-group (pie: one
// group per ring; radial: one per band). Mid-sweep paths are plain
// sectors; the exact server d (corner rounding included) is restored on
// the final frame.
//
// MORPH (A-W3). Charts with a stable id keep their last geometry in a
// module registry when they disconnect; when a same-id chart connects
// within the freshness window (any same-context DOM swap - Turbo Drive /
// Frames / Streams / morph), the new render starts FROM the old geometry
// and tweens to its own: paths by pairwise numeric lerp (structure
// fingerprint must match), sectors by param lerp through the same
// sectorPath, dots by cx/cy. Any structure change aborts the morph and
// the normal entrance replays instead (recharts-faithful for added or
// removed data). The client still computes NO chart geometry - both
// endpoints are server renders; the only math is a + (b - a) * t.
//
// prefers-reduced-motion (or animate: false) settles immediately - the
// server-rendered chart is already the finished state.

const MORPH_SLOTS = [
  "chart-area",
  "chart-area-stroke",
  "chart-line",
  "chart-bar",
  "chart-radar",
  "chart-pie-sector",
  "chart-radial-bar",
  "chart-dot",
]
const MORPH_SELECTOR = MORPH_SLOTS.map((slot) => `[data-slot="${slot}"]`).join(", ")
const MORPH_WINDOW_MS = 5000

// chartId -> { at, entries } across controller lifetimes (module-scoped:
// the old render's controller writes it on disconnect, the new render's
// reads it on connect - same JS context, so Turbo swaps carry it over).
const registry = new Map()

const NUMBER = /-?(?:\d+\.?\d*|\.\d+)(?:e[-+]?\d+)?/gi

// d -> { skeleton, numbers }: the non-numeric shape (command letters and
// separators) plus the numbers in order. Equal skeletons morph; arc flags
// are structural constants inside the skeleton's A-segments and stay put
// under lerp because equal skeletons imply equal flags.
function parsePath(d) {
  const numbers = []
  const skeleton = d.replace(NUMBER, (match) => {
    numbers.push(Number(match))
    return "#"
  })
  return { skeleton, numbers }
}

function buildPath(skeleton, numbers) {
  let i = 0
  return skeleton.replace(/#/g, () => String(Math.round(numbers[i++] * 100) / 100))
}

export default class ChartMotionController extends Controller {
  connect() {
    this.svg = this.element.querySelector('[data-slot="chart-svg"]')
    if (!this.svg) return
    this.chartId = this.element.closest("[data-chart]")?.dataset.chart

    if (!this.svg.hasAttribute("data-animate") || this.#reducedMotion()) {
      this.#settle()
      return
    }

    if (this.#morphFromRegistry()) return

    const sectors = [...this.svg.querySelectorAll("[data-motion-sector]")]
    if (sectors.length) this.#sweep(sectors)
    else this.#watchCssEntrance()
  }

  disconnect() {
    this.cancel?.()
    this.cancel = null
    if (this.chartId && this.svg) {
      registry.set(this.chartId, { at: performance.now(), entries: this.#capture() })
    }
  }

  // -- the cross-render morph (A-W3) ----------------------------------------

  #morphFromRegistry() {
    if (!this.chartId) return false
    const previous = registry.get(this.chartId)
    if (!previous) return false
    registry.delete(this.chartId)
    if (performance.now() - previous.at > MORPH_WINDOW_MS) return false

    const jobs = this.#matchJobs(previous.entries)
    if (!jobs) return false

    // Stamped before the first paint of the new render, so the morph-kill
    // CSS rule suppresses the entrance animations that would otherwise
    // start on the fresh elements.
    this.svg.setAttribute("data-motion", "morph")

    const frame = (eased) => {
      for (const job of jobs) {
        if (job.sector) {
          const p = job.from.map((from, i) => from + (job.to[i] - from) * eased)
          job.el.setAttribute("d", sectorPath(p[0], p[1], p[2], p[3], p[4], p[5]))
        } else if (job.skeleton) {
          const numbers = job.from.map((from, i) => from + (job.to[i] - from) * eased)
          job.el.setAttribute("d", buildPath(job.skeleton, numbers))
        } else {
          job.el.setAttribute("cx", String(job.from[0] + (job.to[0] - job.from[0]) * eased))
          job.el.setAttribute("cy", String(job.from[1] + (job.to[1] - job.from[1]) * eased))
        }
      }
    }
    frame(0) // FLIP: the new render starts at the OLD geometry, synchronously

    this.cancel = tween({
      duration: this.#number("--poetry-motion-duration", 1500),
      easing: this.#styleVar("--poetry-motion-easing") ?? "ease",
      onFrame: frame,
      onFinish: () => {
        for (const job of jobs) {
          if (job.final != null) job.el.setAttribute("d", job.final)
          else {
            job.el.setAttribute("cx", job.finalCx)
            job.el.setAttribute("cy", job.finalCy)
          }
        }
        this.#settle()
      },
    })
    return true
  }

  // Snapshot the animatable geometry, keyed by slot + series key +
  // per-bucket sequence (dots carry no index; document order is stable).
  #capture() {
    const entries = new Map()
    for (const [key, el] of this.#keyedElements()) {
      if (el.dataset.motionSector) {
        entries.set(key, { sector: el.dataset.motionSector.split(" ").map(Number) })
      } else if (el.hasAttribute("d")) {
        entries.set(key, { d: el.getAttribute("d") })
      } else if (el.hasAttribute("cx")) {
        entries.set(key, { cx: Number(el.getAttribute("cx")), cy: Number(el.getAttribute("cy")) })
      }
    }
    return entries
  }

  // Pair every animatable element with its captured predecessor. Null =
  // structure changed (missing key, skeleton mismatch, kind mismatch) ->
  // the caller falls back to the entrance replay.
  #matchJobs(previous) {
    const jobs = []
    for (const [key, el] of this.#keyedElements()) {
      const before = previous.get(key)
      if (!before) return null

      if (el.dataset.motionSector && before.sector) {
        const to = el.dataset.motionSector.split(" ").map(Number)
        if (to.length !== before.sector.length) return null
        jobs.push({ el, sector: true, from: before.sector, to, final: el.getAttribute("d") })
      } else if (el.hasAttribute("d") && before.d != null) {
        const from = parsePath(before.d)
        const to = parsePath(el.getAttribute("d"))
        if (from.skeleton !== to.skeleton) return null
        jobs.push({ el, skeleton: to.skeleton, from: from.numbers, to: to.numbers, final: el.getAttribute("d") })
      } else if (el.hasAttribute("cx") && before.cx != null) {
        jobs.push({
          el,
          from: [before.cx, before.cy],
          to: [Number(el.getAttribute("cx")), Number(el.getAttribute("cy"))],
          finalCx: el.getAttribute("cx"),
          finalCy: el.getAttribute("cy"),
        })
      } else {
        return null
      }
    }
    return jobs.length ? jobs : null
  }

  *#keyedElements() {
    const counters = new Map()
    for (const el of this.svg.querySelectorAll(MORPH_SELECTOR)) {
      const base = `${el.dataset.slot}|${el.dataset.key ?? ""}`
      const n = counters.get(base) ?? 0
      counters.set(base, n + 1)
      yield [`${base}|${n}`, el]
    }
  }

  // -- the polar fan-out (A-W2) -----------------------------------------

  #sweep(elements) {
    const groups = new Map()
    for (const el of elements) {
      const [cx, cy, inner, outer, start, end] = el.dataset.motionSector.split(" ").map(Number)
      const key = el.dataset.motionGroup ?? "all"
      if (!groups.has(key)) groups.set(key, [])
      groups.get(key).push({ el, cx, cy, inner, outer, start, end, final: el.getAttribute("d") })
    }

    // Hold the entrance state through animation_begin (recharts renders
    // the delay at the entrance state, not the finished chart).
    this.svg.setAttribute("data-motion", "entrance")
    const frame = (eased) => {
      for (const sectors of groups.values()) {
        let cursor = sectors[0].start
        let previousEnd = sectors[0].start
        for (const s of sectors) {
          const pad = s.start - previousEnd
          const delta = (s.end - s.start) * eased
          const from = cursor + pad
          s.el.setAttribute("d", sectorPath(s.cx, s.cy, s.inner, s.outer, from, from + delta))
          previousEnd = s.end
          cursor = from + delta
        }
      }
    }
    frame(0)

    this.cancel = tween({
      duration: this.#number("--poetry-motion-duration", 1500),
      delay: this.#number("--poetry-motion-delay", 0),
      easing: this.#styleVar("--poetry-motion-easing") ?? "ease",
      onFrame: frame,
      onFinish: () => {
        for (const sectors of groups.values()) {
          for (const s of sectors) s.el.setAttribute("d", s.final)
        }
        this.#settle()
      },
    })
  }

  // -- the CSS entrance observer ------------------------------------------

  #watchCssEntrance() {
    if (typeof this.svg.getAnimations !== "function") {
      this.#settle()
      return
    }
    const animations = this.svg
      .getAnimations({ subtree: true })
      .filter((a) => a.animationName?.startsWith("poetry-chart"))
    if (!animations.length) {
      this.#settle()
      return
    }
    this.svg.setAttribute("data-motion", "entrance")
    Promise.allSettled(animations.map((a) => a.finished)).then(() => {
      if (this.svg.isConnected) this.#settle()
    })
  }

  // -- shared ---------------------------------------------------------------

  #settle() {
    this.svg.setAttribute("data-motion", "settled")
    this.dispatch("settled")
  }

  // The --poetry-motion-* knobs ride the SVG's inline style - our own wire
  // format, so parse the attribute (jsdom-safe, the tooltip's viewBox lesson).
  #styleVar(name) {
    const match = (this.svg.getAttribute("style") ?? "").match(new RegExp(`${name}:\\s*([^;]+)`))
    return match ? match[1].trim() : null
  }

  #number(name, fallback) {
    const value = parseFloat(this.#styleVar(name))
    return Number.isFinite(value) ? value : fallback
  }

  #reducedMotion() {
    return typeof matchMedia === "function" && matchMedia("(prefers-reduced-motion: reduce)").matches
  }
}
