import { sectorPath } from "@poetry/charts/motion/sector"

// The FLIP geometry machinery (shared by the motion and live tiers):
// snapshot a chart's animatable geometry, pair it against the
// current DOM, and tween old -> new. Paths morph by pairwise numeric lerp
// behind a structure fingerprint, sectors by param lerp through the same
// sectorPath port, dots by cx/cy. Both endpoints are always
// server-computed (or kernel-computed) states - the only math here is
// a + (b - a) * t.

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
/** Selector matching every animatable mark the FLIP machinery drives. */
export const MORPH_SELECTOR = MORPH_SLOTS.map((slot) => `[data-slot="${slot}"]`).join(", ")

const NUMBER = /-?(?:\d+\.?\d*|\.\d+)(?:e[-+]?\d+)?/gi

/**
 * d -> { skeleton, numbers }: the non-numeric shape (command letters
 * and separators) plus the numbers in order. Equal skeletons morph; arc
 * flags are structural constants inside the skeleton's A-segments and
 * stay put under lerp because equal skeletons imply equal flags.
 *
 * @param {string} d
 * @returns {{ skeleton: string, numbers: number[] }}
 */
export function parsePath(d) {
  const numbers = []
  const skeleton = d.replace(NUMBER, (match) => {
    numbers.push(Number(match))
    return "#"
  })
  return { skeleton, numbers }
}

/**
 * Rebuilds a d string from a skeleton and numbers (2-decimal rounding).
 *
 * @param {string} skeleton
 * @param {number[]} numbers
 * @returns {string}
 */
export function buildPath(skeleton, numbers) {
  let i = 0
  return skeleton.replace(/#/g, () => String(Math.round(numbers[i++] * 100) / 100))
}

/**
 * Yields [key, element] for every animatable element, keyed by slot +
 * series key + per-bucket sequence (dots carry no index; document order
 * is stable).
 *
 * @param {SVGElement} svg
 * @returns {Generator<[string, Element]>}
 */
export function* keyedElements(svg) {
  const counters = new Map()
  for (const el of svg.querySelectorAll(MORPH_SELECTOR)) {
    const base = `${el.dataset.slot}|${el.dataset.key ?? ""}`
    const n = counters.get(base) ?? 0
    counters.set(base, n + 1)
    yield [`${base}|${n}`, el]
  }
}

/**
 * Snapshots the animatable geometry (sector params, path d, or dot
 * cx/cy), keyed for pairing.
 *
 * @param {SVGElement} svg
 * @returns {Map<string, Object>}
 */
export function captureGeometry(svg) {
  const entries = new Map()
  for (const [key, el] of keyedElements(svg)) {
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

/**
 * Pairs every animatable element with its captured predecessor. Null =
 * structure changed (missing key, skeleton mismatch, kind mismatch) -
 * the caller falls back to its non-morph path.
 *
 * @param {SVGElement} svg
 * @param {Map<string, Object>} previous - from `captureGeometry`
 * @returns {Array<Object> | null} tween jobs, or null
 */
export function matchJobs(svg, previous) {
  const jobs = []
  for (const [key, el] of keyedElements(svg)) {
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

/**
 * Writes one interpolated frame of every job onto the DOM.
 *
 * @param {Array<Object>} jobs
 * @param {number} eased - 0..1
 */
export function applyJobs(jobs, eased) {
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

/**
 * The final frame restores the exact target strings (server- or
 * kernel-rendered), never a lerp artifact.
 *
 * @param {Array<Object>} jobs
 */
export function finishJobs(jobs) {
  for (const job of jobs) {
    if (job.final != null) job.el.setAttribute("d", job.final)
    else {
      job.el.setAttribute("cx", job.finalCx)
      job.el.setAttribute("cy", job.finalCy)
    }
  }
}
