import { Controller } from "@hotwired/stimulus"
import { teardown, scopeOf } from "@poetry/controllers/helpers/scope"
import { useLayout } from "@poetry/motion/behaviors/layout"

/**
 * Animated list: a Turbo Stream that changes the list (append, prepend,
 * remove, replace, update, or a refresh that morphs it) runs as a layout
 * transition, so new items fade in, removed items fade out and the rest
 * slide to their new places. The server renders the list as it is; the
 * stream's own render does the change, and the transition only animates
 * it. Reduced motion and a running Turbo visit apply the change directly.
 */
export default class AnimatedListController extends Controller {
  static values = {
    // Milliseconds for each transition.
    duration: { type: Number, default: 300 }
  }

  /**
   * Starts wrapping the streams that touch this list.
   *
   * @returns {void}
   */
  connect() {
    const layout = useLayout(this, { duration: this.durationValue })
    const items = `[data-animated-list="${this.element.dataset.animatedList}"] > *`
    scopeOf(this).listen(document, "turbo:before-stream-render", (event) => {
      if (!this.#touches(event.target)) return
      const render = event.detail.render
      event.detail.render = (stream) => layout(() => render(stream), (view) => {
        view.add(items)
          .enter({ opacity: [0, 1], scale: [0.96, 1] })
          .exit({ opacity: [1, 0], scale: [1, 0.96] })
      })
    })
  }

  /**
   * Stops wrapping streams.
   *
   * @returns {void}
   */
  disconnect() {
    teardown(this)
  }

  // Whether the stream targets this list or something inside it.
  #touches(stream) {
    const targets = stream.targetElements ?? []
    return targets.some((target) => target === this.element || this.element.contains(target))
  }
}
