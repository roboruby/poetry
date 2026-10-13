// useCanvas: the canvas pattern. One <canvas> sized to its box at the
// device pixel ratio (core's useMeasure), a frame loop paused off screen
// and in hidden tabs (useFrame), and one static frame under reduced
// motion. Canvas pixels never reach a Turbo snapshot, so the cache needs
// nothing; the canvas is drawn again on the next connect.
import { scopeOf } from "@poetry/controllers/helpers/scope"
import { useMeasure } from "@poetry/controllers/behaviors/measure"
import { useFrame } from "@poetry/motion/behaviors/frame"
import { prefersReducedMotion } from "@poetry/motion/policy"

/**
 * Drives `draw` on `canvas` until teardown(controller).
 *
 * @param {Object} controller - the Stimulus controller instance
 * @param {HTMLCanvasElement} canvas - the canvas
 * @param {(context: CanvasRenderingContext2D, frame: { width: number, height: number, time: number, delta: number }) => void} draw
 * @returns {{ redraw: () => void }}
 */
export function useCanvas(controller, canvas, draw) {
  const context = canvas.getContext?.("2d")
  const size = { width: 0, height: 0 }
  let time = 0

  const paint = (delta = 0) => {
    if (!context || size.width === 0) return
    draw(context, { ...size, time, delta })
  }

  useMeasure(controller, canvas, ({ width, height }) => {
    const ratio = window.devicePixelRatio || 1
    size.width = width
    size.height = height
    canvas.width = Math.round(width * ratio)
    canvas.height = Math.round(height * ratio)
    context?.setTransform(ratio, 0, 0, ratio, 0, 0)
    paint()
  })

  if (!prefersReducedMotion()) {
    useFrame(controller, canvas, (timestamp, delta) => {
      time = timestamp
      paint(delta)
    })
  }
  scopeOf(controller).defer(() => context?.clearRect(0, 0, canvas.width, canvas.height))

  return { redraw: () => paint() }
}
