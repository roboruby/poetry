import { Controller } from "@hotwired/stimulus"
import { teardown, scopeOf } from "@poetry/controllers/helpers/scope"
import { useBeforeCache } from "@poetry/controllers/behaviors/before_cache"
import { loadConfetti } from "@poetry/motion/load_engine"
import { prefersReducedMotion, entranceAllowed } from "@poetry/motion/policy"

/**
 * Confetti: a burst over the page from the server-rendered, full-viewport
 * canvas - on a click inside the effect (from where the click landed), or
 * once when it connects (trigger "load": a success message a Turbo Stream
 * rendered). The canvas-confetti kernel loads on the first burst. Reduced
 * motion, a cache preview and a restore visit burst nothing; teardown and
 * the Turbo cache clear the canvas.
 */
export default class ConfettiController extends Controller {
  static targets = ["canvas"]

  static values = {
    // When it bursts: "click" or "load".
    trigger: { type: String, default: "click" },
    // How many pieces per burst.
    count: { type: Number, default: 120 },
    // The burst's spread, in degrees.
    spread: { type: Number, default: 70 }
  }

  /**
   * Arms the burst.
   *
   * @returns {void}
   */
  connect() {
    if (!this.hasCanvasTarget) return

    const scope = scopeOf(this)
    let cannon = null
    let stopped = false
    const clear = () => cannon?.reset()
    scope.defer(() => {
      stopped = true
      clear()
    })
    useBeforeCache(this, clear)

    const burst = async (origin) => {
      if (prefersReducedMotion()) return
      const { create } = await loadConfetti()
      if (stopped) return
      cannon ??= create(this.canvasTarget, { resize: true, useWorker: false, disableForReducedMotion: true })
      cannon({ particleCount: this.countValue, spread: this.spreadValue, origin })
    }

    if (this.triggerValue === "load") {
      if (entranceAllowed()) burst({ x: 0.5, y: 0.6 })
      return
    }
    scope.listen(this.element, "click", (event) => {
      const fromKeyboard = event.detail === 0
      const rect = this.element.getBoundingClientRect()
      const x = fromKeyboard ? rect.left + rect.width / 2 : event.clientX
      const y = fromKeyboard ? rect.top + rect.height / 2 : event.clientY
      burst({ x: x / window.innerWidth, y: y / window.innerHeight })
    })
  }

  /**
   * Disarms and clears the canvas.
   *
   * @returns {void}
   */
  disconnect() {
    teardown(this)
  }
}
