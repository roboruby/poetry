import { Controller } from "@hotwired/stimulus"
import { chartAdapter } from "@poetry/charts/adapter_registry"

// The adapter mount: reads the FROZEN chart-spec v1 the
// server embedded, hands it to the registered engine adapter, and owns
// the lifecycle - render on connect, destroy on disconnect (Turbo-safe),
// themeChanged on dark-mode flips. The helpers close the canvas gap:
// resolveColor turns var(--color-key)/var(--chart-N) into concrete
// values at paint time (CSS variables cannot reach a canvas).
export default class ChartAdapterController extends Controller {
  // The events this controller dispatches (manifest surface;
  // events_declaration.test.js enforces the list stays honest).
  static events = ["poetry--charts--adapter:rendered"]

  static targets = ["mount", "spec"]
  static values = { engine: String }

  /**
   * Mounts the declared engine: parses the embedded spec, validates the
   * adapter and its type support (console errors, never throws - a
   * chart must not take the page down), renders, and arms the dark-mode
   * observer.
   */
  connect() {
    const adapter = chartAdapter(this.engineValue)
    if (!adapter) {
      console.error(`poetry-charts: no adapter registered for engine ${JSON.stringify(this.engineValue)} - ` +
        "register one with registerChartAdapter(name, adapter) before charts connect")
      return
    }

    this.adapter = adapter
    this.spec = JSON.parse(this.specTarget.textContent)

    if (adapter.supports && !adapter.supports.includes(this.spec.type)) {
      console.error(`poetry-charts: the ${this.engineValue} adapter does not support ${this.spec.type} charts ` +
        `(supports: ${adapter.supports.join(", ")})`)
      return
    }

    this.instance = adapter.render(this.mountTarget, this.spec, this.#helpers())
    this.#observeTheme()
    this.dispatch("rendered", { detail: { engine: this.engineValue, degradations: adapter.degradations ?? [] } })
  }

  /** Destroys the engine instance and stops the theme observer. */
  disconnect() {
    this.observer?.disconnect()
    if (this.instance != null) this.adapter?.destroy(this.instance, this.mountTarget)
    this.instance = null
  }

  // Dark-mode flips re-enter the adapter (canvas engines must repaint -
  // resolved colors are frozen pixels, unlike our SVG's live CSS vars).
  #observeTheme() {
    if (typeof this.adapter.themeChanged !== "function") return

    this.observer = new MutationObserver(() => {
      this.instance = this.adapter.themeChanged(this.instance, this.spec, this.#helpers()) ?? this.instance
    })
    this.observer.observe(document.documentElement, { attributes: true, attributeFilter: ["class"] })
  }

  #helpers() {
    const scope = this.element.closest("[data-chart]") ?? this.element
    return {
      // var(--color-desktop) / var(--chart-1) / #hex -> a concrete color.
      resolveColor: (color) => {
        const match = /^var\((--[\w-]+)\)$/.exec(color ?? "")
        if (!match) return color
        return getComputedStyle(scope).getPropertyValue(match[1]).trim() || color
      },
    }
  }
}
