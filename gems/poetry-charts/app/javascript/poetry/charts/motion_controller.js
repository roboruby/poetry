import { Controller } from "@hotwired/stimulus"
import { tween } from "@poetry/charts/motion/tween"
import { sectorPath } from "@poetry/charts/motion/sector"
import { captureGeometry, matchJobs, applyJobs, finishJobs } from "@poetry/charts/motion/flip"

// The chart motion engine: the JS half of the entrance tier plus
// the cross-render morph. Cartesian + radar entrances are pure CSS (the
// motion stylesheet); this controller adds what CSS cannot do - the polar
// fan-out and the FLIP morph between server renders - and stamps a
// data-motion lifecycle attribute ("entrance" / "morph" -> "settled") on
// the SVG so tests and hosts can observe the engine.
//
// ENTRANCE. The fan-out is recharts' Pie stepData accumulator
// (Pie.tsx): every sector's angular width interpolates 0 -> final
// simultaneously, re-accumulated end-to-end each frame from the group's
// first startAngle, with the FINAL-geometry gaps preserved as constant
// padding. Sectors carry their server-computed params in
// data-motion-sector and their sweep group in data-motion-group (pie: one
// group per ring; radial: one per band). Mid-sweep paths are plain
// sectors; the exact server d (corner rounding included) is restored on
// the final frame.
//
// MORPH. Charts with a stable id keep their last geometry in a
// module registry when they disconnect; when a same-id chart connects
// within the freshness window (any same-context DOM swap - Turbo Drive /
// Frames / Streams / morph), the new render starts FROM the old geometry
// and tweens to its own via the shared FLIP machinery (motion/flip.js -
// the live tier rides the same module). Any structure change
// aborts the morph and the normal entrance replays instead
// (recharts-faithful for added or removed data).
//
// prefers-reduced-motion (or animate: false) settles immediately - the
// server-rendered chart is already the finished state.

const MORPH_WINDOW_MS = 5000

// chartId -> { at, entries } across controller lifetimes (module-scoped:
// the old render's controller writes it on disconnect, the new render's
// reads it on connect - same JS context, so Turbo swaps carry it over).
const registry = new Map()

export default class ChartMotionController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry--charts--motion:settled"]

  #onBeforeRender = null
  #onTurboMorph = null

  connect() {
    this.svg = this.element.querySelector('[data-slot="chart-svg"]')
    if (!this.svg) return
    this.chartId = this.element.closest("[data-chart]")?.dataset.chart

    // A Turbo PAGE morph preserves this element (no disconnect/connect),
    // yet replaces the SVG - without these hooks the fresh render replays
    // the CSS entrance from blank (the area chart's scaleX(0) frame).
    // Capture geometry before the morph, then rejoin the normal flow.
    this.#onBeforeRender = (event) => {
      if (event.detail?.renderMethod !== "morph") return
      if (this.chartId && this.svg?.isConnected) {
        registry.set(this.chartId, { at: performance.now(), entries: captureGeometry(this.svg) })
      }
    }
    this.#onTurboMorph = () => this.#restartAfterTurboMorph()
    document.addEventListener("turbo:before-render", this.#onBeforeRender)
    document.addEventListener("turbo:morph", this.#onTurboMorph)

    this.#start()
  }

  #start() {
    if (!this.svg.hasAttribute("data-animate") || this.#reducedMotion()) {
      this.#settle()
      return
    }

    if (this.#morphFromRegistry()) return

    const sectors = [...this.svg.querySelectorAll("[data-motion-sector]")]
    if (sectors.length) this.#sweep(sectors)
    else this.#watchCssEntrance()
  }

  #restartAfterTurboMorph() {
    const svg = this.element.querySelector('[data-slot="chart-svg"]')
    if (!svg) return

    this.cancel?.()
    this.cancel = null
    this.svg = svg
    this.#start()
  }

  disconnect() {
    document.removeEventListener("turbo:before-render", this.#onBeforeRender)
    document.removeEventListener("turbo:morph", this.#onTurboMorph)
    this.cancel?.()
    this.cancel = null
    if (this.chartId && this.svg) {
      registry.set(this.chartId, { at: performance.now(), entries: captureGeometry(this.svg) })
    }
  }

  // -- the cross-render morph -----------------------------------------------

  #morphFromRegistry() {
    if (!this.chartId) return false
    const previous = registry.get(this.chartId)
    if (!previous) return false
    registry.delete(this.chartId)
    if (performance.now() - previous.at > MORPH_WINDOW_MS) return false

    const jobs = matchJobs(this.svg, previous.entries)
    if (!jobs) return false

    // Stamped before the first paint of the new render, so the morph-kill
    // CSS rule suppresses the entrance animations that would otherwise
    // start on the fresh elements.
    this.svg.setAttribute("data-motion", "morph")
    applyJobs(jobs, 0) // FLIP: the new render starts at the OLD geometry

    this.cancel = tween({
      duration: this.#number("--poetry-motion-duration", 1500),
      easing: this.#styleVar("--poetry-motion-easing") ?? "ease",
      onFrame: (eased) => applyJobs(jobs, eased),
      onFinish: () => {
        finishJobs(jobs)
        this.#settle()
      },
    })
    return true
  }

  // -- the polar fan-out ------------------------------------------------

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
