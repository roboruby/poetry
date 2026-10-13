import { Controller } from "@hotwired/stimulus"
import { teardown, scopeOf } from "@poetry/controllers/helpers/scope"
import { useMeasure } from "@poetry/controllers/behaviors/measure"
import { useFrame } from "@poetry/motion/behaviors/frame"
import { loadGlobe } from "@poetry/motion/load_engine"
import { prefersReducedMotion } from "@poetry/motion/policy"

/**
 * Globe: a dotted, turning globe with markers, drawn by the cobe kernel
 * (WebGL) on the server-rendered canvas. It turns through useFrame, so it
 * pauses off screen and in hidden tabs, and reduced motion draws it once,
 * still. The kernel loads when the globe connects; teardown destroys the
 * WebGL context. It follows the page's dark class.
 */
export default class GlobeController extends Controller {
  static targets = ["canvas"]

  static values = {
    // [[latitude, longitude], ...] for the markers.
    markers: { type: Array, default: [] },
    // Radians per second it turns.
    speed: { type: Number, default: 0.3 },
    // Its starting tilt toward the viewer, in radians.
    tilt: { type: Number, default: 0.25 }
  }

  /**
   * Builds the globe and starts it turning.
   *
   * @returns {void}
   */
  connect() {
    if (!this.hasCanvasTarget) return

    const canvas = this.canvasTarget
    const scope = scopeOf(this)
    let globe = null
    let stopped = false
    let phi = 0
    let size = 0
    scope.defer(() => {
      stopped = true
      globe?.destroy()
    })

    loadGlobe().then(({ createGlobe }) => {
      if (stopped) return
      const ratio = Math.min(window.devicePixelRatio || 1, 2)
      size = canvas.getBoundingClientRect().width
      const dark = document.documentElement.classList.contains("dark") ? 1 : 0
      globe = createGlobe(canvas, {
        devicePixelRatio: ratio, width: size * ratio, height: size * ratio, phi, theta: this.tiltValue, dark,
        diffuse: 1.2, mapSamples: 16000, mapBrightness: 6, baseColor: dark ? [0.3, 0.3, 0.3] : [1, 1, 1],
        markerColor: [0.1, 0.5, 1], glowColor: dark ? [0.2, 0.2, 0.2] : [1, 1, 1],
        markers: this.markersValue.map((location) => ({ location, size: 0.05 }))
      })
      globe.update({ phi })
      if (prefersReducedMotion()) return
      useFrame(this, canvas, (_timestamp, delta) => {
        phi += (this.speedValue * (delta || 16)) / 1000
        globe.update({ phi })
      })
    })
    useMeasure(this, canvas, ({ width }) => {
      if (!globe || width === size) return
      size = width
      const ratio = Math.min(window.devicePixelRatio || 1, 2)
      globe.update({ width: width * ratio, height: width * ratio })
    })
  }

  /**
   * Stops turning and releases the WebGL context.
   *
   * @returns {void}
   */
  disconnect() {
    teardown(this)
  }
}
