import { Controller } from "@hotwired/stimulus"
import { tween } from "@poetry/charts/motion/tween"
import { sectorPath } from "@poetry/charts/motion/sector"

// The chart motion engine (Phase A-W2): the JS half of the entrance tier.
// Cartesian + radar entrances are pure CSS (the motion stylesheet); this
// controller adds what CSS cannot do - the polar fan-out - and stamps a
// data-motion lifecycle attribute ("entrance" -> "settled") on the SVG so
// tests and hosts can observe the engine.
//
// The fan-out is recharts' Pie stepData accumulator (Pie.tsx): every
// sector's angular width interpolates 0 -> final simultaneously,
// re-accumulated end-to-end each frame from the group's first startAngle,
// with the FINAL-geometry gaps preserved as constant padding. Sectors
// carry their server-computed params in data-motion-sector and their
// sweep group in data-motion-group (pie: one group per ring; radial: one
// per band) - the client reads embedded geometry, it never computes any.
// Mid-sweep paths are plain sectors; the exact server d (corner rounding
// included) is restored on the final frame.
//
// prefers-reduced-motion (or animate: false) settles immediately - the
// server-rendered chart is already the finished state.
export default class ChartMotionController extends Controller {
  connect() {
    this.svg = this.element.querySelector('[data-slot="chart-svg"]')
    if (!this.svg) return

    if (!this.svg.hasAttribute("data-animate") || this.#reducedMotion()) {
      this.#settle()
      return
    }

    const sectors = [...this.svg.querySelectorAll("[data-motion-sector]")]
    if (sectors.length) this.#sweep(sectors)
    else this.#watchCssEntrance()
  }

  disconnect() {
    this.cancel?.()
    this.cancel = null
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
