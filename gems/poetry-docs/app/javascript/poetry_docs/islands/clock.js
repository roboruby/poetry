// A fill island for the Islands page: a clock face painted on a canvas in
// the shell's box, in the page's own text color. The server's shell shows
// the time as text; the island paints hands over the same box and gives it
// back on unmount. Reduced motion redraws once a second instead of every
// frame.

/**
 * Mounts the clock.
 * @param {HTMLElement} element the root the island paints
 * @param {Object} props the island's props: `seconds: false` hides the second hand
 * @returns {{ unmount: Function, update: Function }} the island's handle
 */
export function mount(element, props) {
  const canvas = document.createElement("canvas")
  canvas.setAttribute("aria-hidden", "true")
  canvas.style.cssText = "display:block;width:100%;height:100%"
  element.append(canvas)
  const context = canvas.getContext("2d")
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
  let seconds = props.seconds !== false
  let next = 0

  const hand = (cx, cy, turns, length, width) => {
    const angle = turns * Math.PI * 2 - Math.PI / 2
    context.lineWidth = width
    context.beginPath()
    context.moveTo(cx, cy)
    context.lineTo(cx + Math.cos(angle) * length, cy + Math.sin(angle) * length)
    context.stroke()
  }

  const draw = () => {
    const { width, height } = element.getBoundingClientRect()
    const scale = window.devicePixelRatio || 1
    if (canvas.width !== Math.round(width * scale) || canvas.height !== Math.round(height * scale)) {
      canvas.width = Math.round(width * scale)
      canvas.height = Math.round(height * scale)
    }
    context.setTransform(scale, 0, 0, scale, 0, 0)
    context.clearRect(0, 0, width, height)
    context.strokeStyle = getComputedStyle(element).color
    context.lineCap = "round"
    const [cx, cy] = [width / 2, height / 2]
    const radius = Math.min(width, height) / 2 - 8
    context.lineWidth = 2
    context.beginPath()
    context.arc(cx, cy, radius, 0, Math.PI * 2)
    context.stroke()
    const now = new Date()
    const second = now.getSeconds() + (reduce ? 0 : now.getMilliseconds() / 1000)
    const minute = now.getMinutes() + second / 60
    const hour = (now.getHours() % 12) + minute / 60
    hand(cx, cy, hour / 12, radius * 0.5, 4)
    hand(cx, cy, minute / 60, radius * 0.75, 3)
    if (seconds) hand(cx, cy, second / 60, radius * 0.9, 1)
    next = reduce ? setTimeout(draw, 1000) : requestAnimationFrame(draw)
  }
  draw()

  return {
    unmount: () => {
      if (reduce) clearTimeout(next)
      else cancelAnimationFrame(next)
      canvas.remove()
    },
    update: (changed) => {
      seconds = changed.seconds !== false
    }
  }
}
