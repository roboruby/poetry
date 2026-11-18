import { Controller } from "@hotwired/stimulus"
import { teardown } from "@poetry/controllers/helpers/scope"
import { useCanvas } from "@poetry/motion/behaviors/canvas"

// A seeded generator (mulberry32): the same field every time, so a still
// frame under reduced motion is the same picture on every visit.
const seeded = (seed) => () => {
  seed = (seed + 0x6d2b79f5) | 0
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed)
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296
}

/**
 * Particles: a field of slow-drifting dots on the server-rendered canvas,
 * optionally linked by faint lines when close - the canvas pattern
 * (useCanvas): sized to its box at the pixel ratio, drawn every visible
 * frame, paused off screen and in hidden tabs, and one still frame under
 * reduced motion. The dots take the canvas's text color.
 */
export default class ParticlesController extends Controller {
  static targets = ["canvas"]

  static values = {
    // How many dots.
    count: { type: Number, default: 60 },
    // Drift speed, in pixels per second.
    speed: { type: Number, default: 12 },
    // Pixels within which two dots are linked by a line; 0 links none.
    link: { type: Number, default: 0 }
  }

  /**
   * Seeds the field and starts drawing.
   *
   * @returns {void}
   */
  connect() {
    if (!this.hasCanvasTarget) return

    const canvas = this.canvasTarget
    const color = getComputedStyle(canvas).color
    const random = seeded(this.countValue * 7919)
    let dots = null
    useCanvas(this, canvas, (context, { width, height, delta }) => {
      dots ??= Array.from({ length: this.countValue }, () => ({
        x: random() * width, y: random() * height,
        dx: (random() - 0.5) * 2, dy: (random() - 0.5) * 2, r: 1 + random() * 1.5
      }))
      const step = (this.speedValue * (delta || 0)) / 1000
      context.clearRect(0, 0, width, height)
      context.fillStyle = color
      context.strokeStyle = color
      for (const dot of dots) {
        dot.x = (dot.x + dot.dx * step + width) % width
        dot.y = (dot.y + dot.dy * step + height) % height
        context.globalAlpha = 0.7
        context.beginPath()
        context.arc(dot.x, dot.y, dot.r, 0, Math.PI * 2)
        context.fill()
      }
      if (this.linkValue > 0) this.#link(context, dots)
    })
  }

  /**
   * Stops drawing and clears the canvas.
   *
   * @returns {void}
   */
  disconnect() {
    teardown(this)
  }

  // Faint lines between dots closer than the link distance.
  #link(context, dots) {
    context.lineWidth = 1
    for (let i = 0; i < dots.length; i++) {
      for (let j = i + 1; j < dots.length; j++) {
        const distance = Math.hypot(dots[i].x - dots[j].x, dots[i].y - dots[j].y)
        if (distance > this.linkValue) continue
        context.globalAlpha = 0.25 * (1 - distance / this.linkValue)
        context.beginPath()
        context.moveTo(dots[i].x, dots[i].y)
        context.lineTo(dots[j].x, dots[j].y)
        context.stroke()
      }
    }
  }
}
