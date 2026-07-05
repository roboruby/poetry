// The tween kernel (Phase A-W2): one rAF loop, the CSS-named cubic-bezier
// easings, cancelable. This is the react-smooth equivalent scoped to
// poetry's doctrine - the client only interpolates between
// server-computed states, so the whole kernel is eased time.

// Newton-Raphson with a bisection fallback - the standard CSS timing
// function solver (the same approach WebKit ships).
export function cubicBezier(x1, y1, x2, y2) {
  const ax = 3 * x1 - 3 * x2 + 1
  const bx = 3 * x2 - 6 * x1
  const cx = 3 * x1
  const ay = 3 * y1 - 3 * y2 + 1
  const by = 3 * y2 - 6 * y1
  const cy = 3 * y1

  const sampleX = (t) => ((ax * t + bx) * t + cx) * t
  const sampleY = (t) => ((ay * t + by) * t + cy) * t
  const sampleDX = (t) => (3 * ax * t + 2 * bx) * t + cx

  const solveT = (x) => {
    let t = x
    for (let i = 0; i < 8; i++) {
      const dx = sampleX(t) - x
      if (Math.abs(dx) < 1e-6) return t
      const d = sampleDX(t)
      if (Math.abs(d) < 1e-6) break
      t -= dx / d
    }
    let lo = 0
    let hi = 1
    t = x
    while (lo < hi) {
      const dx = sampleX(t) - x
      if (Math.abs(dx) < 1e-6) return t
      if (dx > 0) hi = t
      else lo = t
      t = (lo + hi) / 2
    }
    return t
  }

  return (x) => {
    if (x <= 0) return 0
    if (x >= 1) return 1
    return sampleY(solveT(x))
  }
}

export const EASINGS = {
  linear: (t) => t,
  ease: cubicBezier(0.25, 0.1, 0.25, 1),
  "ease-in": cubicBezier(0.42, 0, 1, 1),
  "ease-out": cubicBezier(0, 0, 0.58, 1),
  "ease-in-out": cubicBezier(0.42, 0, 0.58, 1),
}

// tween({ duration, delay, easing, onFrame, onFinish }) -> cancel().
// onFrame receives (eased, linear); the final frame is exactly (1, 1).
export function tween({ duration, delay = 0, easing = "ease", onFrame, onFinish }) {
  const fn = typeof easing === "function" ? easing : (EASINGS[easing] ?? EASINGS.ease)

  if (!(duration > 0)) {
    onFrame(1, 1)
    onFinish?.()
    return () => {}
  }

  let raf
  let start
  const step = (now) => {
    start ??= now
    const elapsed = now - start - delay
    if (elapsed < 0) {
      raf = requestAnimationFrame(step)
      return
    }
    const t = Math.min(1, elapsed / duration)
    onFrame(fn(t), t)
    if (t < 1) raf = requestAnimationFrame(step)
    else onFinish?.()
  }
  raf = requestAnimationFrame(step)
  return () => cancelAnimationFrame(raf)
}
